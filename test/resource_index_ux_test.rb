# frozen_string_literal: true

require_relative "test_helper"
require "uri"

class ResourceIndexUxTest < ActionDispatch::IntegrationTest
  setup do
    @password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    16.times do |n|
      User.create!(organization: @acme, name: "Demo User #{n.to_s.rjust(2, "0")}",
        email: "demo-ux-#{n}@example.test",
        status: n.even? ? "active" : "suspended",
        role: n % 3 == 0 ? "admin" : "member",
        verified: n.even?)
    end
    User.create!(organization: @globex, name: "Other Tenant Secret",
      email: "foreign-ux@example.test", status: "active", role: "admin")
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @password }

  def auth
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials("acme", "test-password") }
  end

  def list(slug = "users", parameters = {})
    get "/backoffice/resources/#{slug}", params: parameters, headers: auth
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def url_params(link)
    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  test "sortable table headers are links with accessible direction and forbidden columns are plain text" do
    list
    assert_response :success

    name = doc.at_css("table.rk-index-table th[aria-sort]") # Default PK not shown.
    assert_nil name

    head = doc.css("table.rk-index-table th").find { |node| node.text.include?("Name") }
    assert head.at_css("a.rk-sort-link")
    assert_equal "Sort by Name ascending", head.at_css("a")["aria-label"]

    verified = doc.css("table.rk-index-table th").find { |node| node.text.strip == "Verified" }
    assert verified
    assert_nil verified.at_css("a.rk-sort-link")

    get head.at_css("a")["href"], headers: auth
    assert_response :success
    header = doc.at_css("table.rk-index-table th[aria-sort='ascending']")
    assert header
    assert_equal "Sort by Name descending", header.at_css("a")["aria-label"]

    get header.at_css("a")["href"], headers: auth
    assert_response :success
    assert doc.at_css("table.rk-index-table th[aria-sort='descending']")
  end

  test "clicking sortable column preserves validated filters and search but resets offset page" do
    list("users", q: "Demo", sort: "email", direction: "desc",
      per_page: "10", page: "2", filters: { status: "active", role: "member" })
    assert_response :success
    link = doc.css("table.rk-index-table th a.rk-sort-link").find do |node|
      node.text.include?("Name")
    end
    args = url_params(link)
    assert_equal "Demo", args.fetch("q")
    assert_equal "10", args.fetch("per_page")
    assert_equal "active", args.dig("filters", "status")
    assert_equal "member", args.dig("filters", "role")
    assert_equal "name", args.fetch("sort")
    assert_equal "asc", args.fetch("direction")
    assert_nil args["page"]
    assert_nil args["cursor"]

    get link["href"], headers: auth
    assert_response :success
    assert doc.at_css("table.rk-index-table th[aria-sort='ascending']")
    assert_not_includes response.body, "Other Tenant Secret"
  end

  test "compact filter disclosure opens only with active filters and chips remove individual values" do
    list
    assert_response :success
    details = doc.at_css("details.rk-index-advanced")
    assert details
    assert_nil details["open"]
    assert details.at_css("summary")

    list("users", q: "Demo", sort: "name", per_page: "10",
      filters: { status: "active", role: "admin" })
    assert_response :success
    details = doc.at_css("details.rk-index-advanced")
    assert details["open"]
    assert_includes details.at_css("summary").text, "2 active"

    chips = doc.css("a.rk-index-filter-chip")
    assert_equal 2, chips.size
    remove_status = chips.find { |chip| chip.text.include?("Status") }
    assert_equal "Remove Status filter", remove_status["aria-label"]
    args = url_params(remove_status)
    assert_nil args.dig("filters", "status")
    assert_equal "admin", args.dig("filters", "role")
    assert_equal "Demo", args.fetch("q")
    assert_equal "name", args.fetch("sort")
    assert_equal "10", args.fetch("per_page")
    assert_nil args["page"]

    get remove_status["href"], headers: auth
    assert_response :success
    assert_equal 1, doc.css("a.rk-index-filter-chip").size
  end

  test "clear filters preserves query and sort; malicious filter input never becomes a chip" do
    list("users", q: "Demo", sort: "email", direction: "desc",
      filters: { status: "invalid-choice", role: "admin" })
    assert_response :success
    assert_equal 1, doc.css("a.rk-index-filter-chip").size
    clear = doc.css(".rk-index-active-filters a").find { |link| link.text == "Clear filters" }
    assert clear
    args = url_params(clear)
    assert_nil args["filters"]
    assert_equal "Demo", args["q"]
    assert_equal "email", args["sort"]
    assert_equal "desc", args["direction"]
    assert_nil args["page"]
    assert_nil args["cursor"]
  end

  test "keyset sort header starts at first cursor page and preserves filters" do
    list("cursor_users", { sort: "name", direction: "asc",
      per_page: "5", filters: { status: "active" } })
    assert_response :success
    next_link = doc.css("nav.rk-pagination a").find { |a| a.text == "Next" }
    assert next_link
    get next_link["href"], headers: auth
    assert_response :success
    assert doc.at_css("table.rk-index-table th[aria-sort='ascending']")
    sort_email = doc.css("table.rk-index-table th a.rk-sort-link").find do |a|
      a.text.include?("Email")
    end
    args = url_params(sort_email)
    assert_equal "email", args.fetch("sort")
    assert_equal "active", args.dig("filters", "status")
    assert_nil args["cursor"]
    assert_nil args["page"]
    get sort_email["href"], headers: auth
    assert_response :success
    assert doc.at_css("table.rk-index-table th[aria-sort='ascending']")
    assert_nil doc.css("nav.rk-pagination a").find { |a| a.text == "Previous" }
  end

  test "responsive table has cell labels and native page navigation" do
    list("users", { sort: "name", direction: "asc", per_page: "10" })
    assert_response :success
    assert_select "table.rk-index-table tbody tr", count: 10
    assert_select "table.rk-index-table tbody td[data-label='Name']", count: 10
    assert_select "table.rk-index-table tbody td[data-label='Actions']", count: 10
    assert_select "nav[aria-label='Pagination'] a[data-rk-index-nav]", text: "Next"

    list("cursor_users", { sort: "name", direction: "asc", per_page: "10" })
    assert_response :success
    assert_select "nav[aria-label='Pagination'] a[data-rk-index-nav]", text: "Next"
  end

  test "optional progressive loader asset is packaged and does not prevent native GET forms" do
    list
    assert_response :success
    assert_select "form[method='get'][data-rk-index-form='true']"
    assert_select "section[data-rk-index] .rk-index-loading[role='status']"
    assert_select "section[data-rk-index] .rk-index-results"
    js = doc.at_css("script[src*='/assets/rekorra/index-']")
    assert js, "Engine should ship the progressive enhancement asset"
    css = doc.at_css("link[rel='stylesheet']")["href"]
    get js["src"]
    assert_response :success
    assert_includes response.body, "markBusy"
    assert_includes response.body, "pageshow"

    get css
    assert_response :success
    assert_includes response.body, ".rk-index-filter-chip"
    assert_includes response.body, ".rk-sort-link"
    assert_includes response.body, "@media (max-width: 650px)"
  end
end
