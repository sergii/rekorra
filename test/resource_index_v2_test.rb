# frozen_string_literal: true

require_relative "test_helper"
require "uri"
require "cgi"

class ResourceIndexV2Test < ActionDispatch::IntegrationTest
  setup do
    @old = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@index.test")
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @old }

  def auth(tenant = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(tenant, "test-password") }
  end

  def create_user(name, status: "active", role: "member", verified: false, org: @acme, at: Time.utc(2026, 10, 21))
    User.create!(organization: org, name: name,
      email: "#{name.downcase.gsub(/[^a-z0-9]/, '-')}-#{SecureRandom.hex(4)}@test.local",
      status: status, role: role, verified: verified, created_at: at, updated_at: at)
  end

  def get_users(tenant: "acme", **params)
    get "/backoffice/resources/users", headers: auth(tenant), params: params
  end

  test "ordinary Users Index exposes its typed controls and tenant scoped rows" do
    create_user("Alice", role: "admin", verified: true)
    create_user("Hidden", org: @globex)
    get_users
    assert_response :success
    assert_select "input[name='q']"
    assert_select "select[name='filters[status]']"
    assert_select "select[name='filters[role]']"
    assert_select "select[name='filters[verified]']"
    assert_select "input[name='filters[created_at_from]']"
    assert_select "input[name='filters[created_at_to]']"
    assert_select "select[name='per_page']"
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, "Alice"
    assert_not_includes response.body, "Hidden"
  end

  test "select boolean and search filters combine using SQL" do
    create_user("Alice Admin", role: "admin", status: "active", verified: true)
    create_user("Alice Member", role: "member", status: "active", verified: true)
    create_user("Alice Inactive", role: "admin", status: "suspended", verified: true)
    create_user("Bob Admin", role: "admin", status: "active", verified: true)
    create_user("Alice Unverified", role: "admin", status: "active", verified: false)

    get_users(q: "Alice", filters: { status: "active", role: "admin", verified: "true" })
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, "Alice Admin"
    assert_not_includes response.body, "Alice Member"
    assert_not_includes response.body, "Alice Inactive"
    assert_not_includes response.body, "Bob Admin"
    assert_not_includes response.body, "Alice Unverified"
  end

  test "date range uses inclusive calendar-day boundaries" do
    create_user("Before Day", at: Time.utc(2026, 10, 20, 23, 59))
    create_user("Inside Day", at: Time.utc(2026, 10, 21, 23, 59))
    create_user("After Day", at: Time.utc(2026, 10, 22, 0, 1))

    get_users(filters: { created_at_from: "2026-10-21", created_at_to: "2026-10-21" })
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, "Inside Day"
    assert_not_includes response.body, "Before Day"
    assert_not_includes response.body, "After Day"
  end

  test "numeric range can be used on ordinary Orders Index" do
    Order.create!(customer: @alice, number: "CHEAP", status: "pending", total_cents: 400)
    Order.create!(customer: @alice, number: "MEDIUM", status: "pending", total_cents: 1000)
    Order.create!(customer: @alice, number: "EXPENSIVE", status: "paid", total_cents: 5000)
    get "/backoffice/resources/orders", headers: auth,
      params: { filters: { total_cents_min: "500", total_cents_max: "1500", status: "pending" } }
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, "MEDIUM"
    assert_not_includes response.body, "CHEAP"
    assert_not_includes response.body, "EXPENSIVE"
  end

  test "invalid filter and sort parameters cannot expand the declared predicates" do
    create_user("Safe", status: "active")
    create_user("Suspended", status: "suspended")
    get_users(sort: "name; DROP TABLE users", direction: "desc",
      filters: { status: "active' OR 1=1--", role: "manager", unknown: "malicious" },
      per_page: "999999")
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 2
    assert_select "select[name='per_page'] option[selected]", text: "25"
    assert User.table_exists?
  end

  test "explicit pagination bounds and stable sorting of equal values" do
    57.times { |i| create_user("Same Name", status: i.even? ? "active" : "suspended") }
    get_users(per_page: 50, page: 1, sort: "name", direction: "asc")
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 50
    assert_select "nav.rk-pagination a", text: "Next"

    get_users(per_page: 50, page: 2, sort: "name", direction: "asc")
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 7
    assert_select "nav.rk-pagination a", text: "Previous"
    assert_select "nav.rk-pagination a", text: "Next", count: 0
  end

  test "Next preserves filters, search, per page and sort" do
    35.times { |i| create_user("Match-#{i}", status: "active", role: "admin", verified: true) }
    create_user("Other", status: "suspended")
    get_users(q: "Match", sort: "name", direction: "desc", per_page: 10,
      filters: { status: "active", verified: "true" })
    assert_response :success
    next_link = Nokogiri::HTML(response.body).css("nav.rk-pagination a").find { |a| a.text == "Next" }
    assert next_link
    params = CGI.parse(URI.parse(next_link["href"]).query)
    assert_equal ["2"], params.fetch("page")
    assert_equal ["10"], params.fetch("per_page")
    assert_equal ["Match"], params.fetch("q")
    assert_equal ["name"], params.fetch("sort")
    assert_equal ["desc"], params.fetch("direction")
    assert_equal ["active"], params.fetch("filters[status]")
    assert_equal ["true"], params.fetch("filters[verified]")
    get next_link["href"], headers: auth
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 10
  end

  test "search escapes SQL LIKE wildcards and unauthorized tenants do not leak" do
    create_user("100% real")
    create_user("1000 real")
    create_user("foreign-account", org: @globex)
    get_users(q: "100%")
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, "100% real"

    get_users(q: "foreign")
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 0
  end

  test "Index DSL validates columns, types, duplicate filters and page size" do
    section = Rekorra::Section.new
    section.filter :status, type: :select, options: %w[active]
    assert_raises(Rekorra::ConfigurationError) do
      section.filter :status, type: :select, options: %w[active]
    end
    section.filter :name, type: :boolean
    assert_raises(Rekorra::ConfigurationError) { section.validate_index!(User) }

    pagination = Rekorra::Index::Pagination.new
    pagination.per_page 101
    assert_raises(Rekorra::ConfigurationError) { pagination.validate! }
    pagination.strategy :keyset
    assert_equal :keyset, pagination.strategy
  end

  test "fifty thousand Users are queried with a bound rather than materialized" do
    now = Time.current
    50.times do |block|
      rows = (1..1000).map do |i|
        n = block * 1000 + i
        { organization_id: @acme.id,
          name: "Bulk #{format('%05d', n)}",
          email: "bulk-#{format('%05d', n)}@index.test",
          status: n.even? ? "active" : "suspended",
          role: "member", verified: false, created_at: now, updated_at: now }
      end
      User.insert_all!(rows)
    end
    queries = []
    subscriber = ->(*args) do
      sql = args.last[:sql].to_s
      queries << sql if sql.match?(/FROM\s+[`"]?users[`"]?/i) && sql.match?(/\ASELECT\b/i)
    end
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get_users(page: 30, per_page: 50, sort: "name", direction: "asc",
        filters: { status: "active" })
    end
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 50
    assert queries.any? { |sql| sql.match?(/\bLIMIT\b/i) && sql.match?(/\bOFFSET\b/i) }
    assert queries.none? { |sql| sql.match?(/COUNT\s*\(/i) }
    assert_operator queries.length, :<=, 3

    # The same 50k scoped rows also support the opt-in keyset strategy.
    keyset_sql = []
    tracker = ->(*args) do
      sql = args.last[:sql].to_s
      keyset_sql << sql if sql.match?(/\ASELECT\b/i) && sql.match?(/FROM\s+[`"]?users[`"]?/i)
    end
    ActiveSupport::Notifications.subscribed(tracker, "sql.active_record") do
      get "/backoffice/resources/cursor_users", headers: auth,
        params: { sort: "name", per_page: "50" }
    end
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 50
    assert keyset_sql.any? { |sql| sql.match?(/\bLIMIT\b/i) }
    assert keyset_sql.none? { |sql| sql.match?(/\bOFFSET\b|\bCOUNT\s*\(/i) }
    assert_operator keyset_sql.length, :<=, 3
  end
end
