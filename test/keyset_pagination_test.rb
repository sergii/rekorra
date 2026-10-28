# frozen_string_literal: true

require_relative "test_helper"
require "uri"
require "cgi"

class KeysetPaginationTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @old_password }

  def auth(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def user(name, org: @acme, status: "active", role: "member")
    User.create!(organization: org, name: name, status: status, role: role,
      email: "#{SecureRandom.hex(8)}@example.test")
  end

  def list(params = {}, tenant: "acme")
    get "/backoffice/resources/cursor_users", headers: auth(tenant), params: params
    response
  end

  def rows
    Nokogiri::HTML(response.body).css("table.rk-table tbody tr").map do |tr|
      tr.at_css("td").text.strip
    end
  end

  def cursor_link(label)
    Nokogiri::HTML(response.body).css("nav.rk-pagination a").find { |node| node.text == label }&.[]("href")
  end

  def params_of(url)
    Rack::Utils.parse_nested_query(URI.parse(url).query)
  end

  test "keyset navigates forward and backward across equal sort values without duplicates" do
    11.times { user("Same") }
    4.times { user("Zed") }

    list({ sort: "name", direction: "asc", per_page: "10" })
    assert_response :success
    assert_equal 10, rows.size
    assert_equal Array.new(10, "Same"), rows
    assert_nil cursor_link("Previous")
    forward = cursor_link("Next")
    assert forward
    assert_includes forward, "cursor="
    assert_nil params_of(forward)["page"]
    first_ids = Nokogiri::HTML(response.body).css("table.rk-table tbody tr td:last-child a").map { |n| n["href"] }

    get forward, headers: auth
    assert_response :success
    assert_equal ["Same"] + Array.new(4, "Zed"), rows
    second_ids = Nokogiri::HTML(response.body).css("table.rk-table tbody tr td:last-child a").map { |n| n["href"] }
    assert_empty first_ids & second_ids
    backward = cursor_link("Previous")
    assert backward
    assert_nil cursor_link("Next")

    get backward, headers: auth
    assert_response :success
    assert_equal 10, rows.size
    restored_ids = Nokogiri::HTML(response.body).css("table.rk-table tbody tr td:last-child a").map { |n| n["href"] }
    assert_equal first_ids, restored_ids
    assert_nil cursor_link("Previous")
  end

  test "descending sort uses PK ascending tie break and supports back navigation" do
    6.times { user("Alpha") }
    7.times { user("Beta") }

    list({ sort: "name", direction: "desc", per_page: "10" })
    assert_response :success
    assert_equal Array.new(7, "Beta") + Array.new(3, "Alpha"), rows
    nxt = cursor_link("Next")
    assert nxt
    get nxt, headers: auth
    assert_response :success
    assert_equal Array.new(3, "Alpha"), rows
    prev = cursor_link("Previous")
    assert prev
    get prev, headers: auth
    assert_equal Array.new(7, "Beta") + Array.new(3, "Alpha"), rows
  end

  test "descending primary-key sort works with no explicit sort query" do
    records = 14.times.map { |n| user("User #{n}") }
    list({ direction: "desc", per_page: "10" })
    assert_response :success
    assert_equal 10, rows.length
    forward = cursor_link("Next")
    assert forward
    get forward, headers: auth
    assert_response :success
    assert_equal 4, rows.length
    assert cursor_link("Previous")
  end

  test "search and filters remain bound in cursor and navigation URL" do
    25.times { |n| user("Match #{n}", role: "admin") }
    user("Match not admin", role: "member")
    list({ q: "Match", sort: "name", direction: "asc", per_page: "10",
      filters: { role: "admin" } })
    assert_response :success
    assert_equal 10, rows.size
    nxt = cursor_link("Next")
    assert nxt
    query = params_of(nxt)
    assert_equal "Match", query["q"]
    assert_equal "admin", query.dig("filters", "role")
    assert_equal "10", query["per_page"]
    assert_equal "name", query["sort"]
    get nxt, headers: auth
    assert_response :success
    assert_equal 10, rows.size
    assert_not_includes rows, "Match not admin"
  end

  test "cursor cannot be replayed by a different tenant or scope" do
    15.times { |n| user("Same #{n}") }
    15.times { |n| user("Same #{n}", org: @globex) }
    list({ sort: "name", per_page: "10" })
    token = params_of(cursor_link("Next")).fetch("cursor")
    list({ sort: "name", per_page: "10", cursor: token }, tenant: "globex")
    assert_response :bad_request
    assert_not_includes response.body, "Same"
  end

  test "changing search, filters, sort, direction or per_page invalidates old cursor" do
    15.times { |n| user("Name #{n}") }
    list({ sort: "name", per_page: "10", filters: { status: "active" } })
    token = params_of(cursor_link("Next")).fetch("cursor")
    [
      { q: "Name" }, { filters: { status: "suspended" } },
      { sort: "email" }, { direction: "desc" }, { per_page: "25" }
    ].each do |change|
      list({ sort: "name", per_page: "10", filters: { status: "active" },
        cursor: token }.merge(change))
      assert_response :bad_request
    end
  end

  test "tampered, oversized and malformed cursor yield 400 not 500" do
    15.times { |n| user("Name #{n}") }
    list({ sort: "name", per_page: "10" })
    token = params_of(cursor_link("Next")).fetch("cursor")
    ["#{token[0..-2]}x", "not-a-cursor", "x" * 5_000].each do |invalid|
      list({ sort: "name", per_page: "10", cursor: invalid })
      assert_response :bad_request
      assert_includes response.body, "Invalid or expired pagination cursor"
    end
  end

  test "expired encrypted cursor is rejected without restarting from first page" do
    15.times { |n| user("Expiry #{n}") }
    list({ sort: "name", per_page: "10" })
    token = params_of(cursor_link("Next")).fetch("cursor")
    travel 2.hours do
      list({ sort: "name", per_page: "10", cursor: token })
      assert_response :bad_request
      assert_includes response.body, "Invalid or expired pagination cursor"
    end
  end

  test "encrypted cursor does not expose email or original key" do
    15.times { |n| user("Same", role: "admin") }
    list({ sort: "email", per_page: "10" })
    token = params_of(cursor_link("Next")).fetch("cursor")
    assert_not_includes token, "@example.test"
    assert_operator token.bytesize, :<, 4_096
  end

  test "keyset refuses unsupported or missing sort columns" do
    bad = Rekorra::Section.new
    bad.field :verified
    bad.sort_by :verified
    bad.pagination { strategy :keyset }
    assert_raises(Rekorra::ConfigurationError) { bad.validate_index!(User) }

    no_sort = Rekorra::Section.new
    no_sort.pagination { strategy :keyset }
    assert_raises(Rekorra::ConfigurationError) { no_sort.validate_index!(User) }
  end

  test "cursor requires host identity even with correct scoped relation" do
    15.times { |n| user("Name #{n}") }
    query = Rekorra::Query.new(resource: CursorUserResource,
      scope: User.where(organization_id: @acme.id),
      search: nil, sort: "name", direction: "asc", page: nil,
      cursor_context: nil, per_page: 10)
    assert_raises(Rekorra::ConfigurationError) { query.call }
  end

  test "keyset pages use bounded ordered SQL without OFFSET or COUNT" do
    105.times { |n| user("Bulk #{format('%04d', n)}") }
    statements = []
    subscriber = ->(*args) do
      sql = args.last[:sql].to_s
      statements << sql if sql.match?(/\ASELECT\b/i) && sql.match?(/FROM "?users"?/i)
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      list({ sort: "name", per_page: "50" })
    end
    assert_response :success
    assert_equal 50, rows.size
    assert statements.any? { |sql| sql.match?(/\bLIMIT\b/i) }
    assert statements.none? { |sql| sql.match?(/\bOFFSET\b|\bCOUNT\s*\(/i) }
    assert_operator statements.size, :<=, 3
    get cursor_link("Next"), headers: auth
    assert_response :success
    assert_equal 50, rows.size
  end

  test "original offset Users Index still supports numbered pages" do
    12.times { |n| user("Name #{n}") }
    get "/backoffice/resources/users", headers: auth, params: { per_page: "10", page: "2" }
    assert_response :success
    assert_select "nav.rk-pagination span", text: /Page 2/
    assert_select "table.rk-table tbody tr", count: 2
  end
end
