# frozen_string_literal: true

# Actual Chromium/Selenium acceptance tests against the mounted Rails demo.
# Separate from the fast Minitest suite so browser dependencies stay test-only.
require_relative "../test_helper"
require "action_dispatch/system_test_case"
require "base64"
require "fileutils"

class ResourceIndexBrowserAcceptanceTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]

  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "browser-acceptance-only"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    36.times do |n|
      User.create!(
        organization: @acme, name: "Demo User #{n.to_s.rjust(2, "0")}",
        email: "browser-user-#{n}@example.test",
        status: n.even? ? "active" : "suspended",
        role: n % 3 == 0 ? "admin" : "member",
        verified: n.even?
      )
    end
    User.create!(organization: @globex, name: "Other Tenant Secret",
      email: "forbidden@example.test", status: "active", role: "admin")

    # The demo host uses HTTP Basic. Chrome visits a real Rails server and
    # receives the credentials through the browser's own request headers.
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setExtraHTTPHeaders",
      headers: { "Authorization" =>
        "Basic #{Base64.strict_encode64('acme:browser-acceptance-only')}" })
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous_password
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled",
      value: false)
  rescue Selenium::WebDriver::Error::WebDriverError
    # Chrome may already be shut down after a failed system test.
  end

  test "desktop sortable headers and real GET filter navigation" do
    visit "/backoffice/resources/users?per_page=10"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_text "Demo User 00"
    assert_no_text "Other Tenant Secret"
    assert_selector "a.rk-sort-link[aria-label='Sort by Name ascending']"

    find("a[aria-label='Sort by Name ascending']").click
    assert_selector "th[aria-sort='ascending'] a.rk-sort-link"
    assert_equal "name", URI.parse(current_url).query.then {
      |query| Rack::Utils.parse_nested_query(query)["sort"]
    }
    assert_selector "a.rk-sort-link[aria-label='Sort by Name descending']"

    find("details.rk-index-advanced summary").click
    find("select[name='filters[status]']").select("active")
    within("form[data-rk-index-form]") { click_button "Apply" }
    assert_selector "details.rk-index-advanced[open]"
    assert_selector "a.rk-index-filter-chip"
    assert_no_text "Other Tenant Secret"
    assert_selector "table.rk-index-table tbody tr"

    find("a[aria-label='Remove Status filter']").click
    assert_no_selector "a.rk-index-filter-chip"
    capture("desktop-users")
  end

  test "mobile widths preserve viewport, legible cards and usable pagination" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    visit "/backoffice/resources/users?per_page=10&sort=name"
    assert_selector "table.rk-index-table tbody tr", count: 10

    viewport = evaluate_script("window.innerWidth")
    document_width = evaluate_script("document.documentElement.scrollWidth")
    assert_equal 390, viewport
    assert_operator document_width, :<=, viewport + 1,
      "Resource Index must not cause horizontal page scrolling"
    assert_equal "block", evaluate_script(
      "getComputedStyle(document.querySelector('.rk-index-table tbody tr')).display")
    assert_selector "table.rk-index-table tbody td[data-label='Name']", count: 10
    assert_selector "nav[aria-label='Pagination'] a", text: "Next"
    capture("mobile-390-users")

    click_link "Next"
    assert_text "Page 2"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_no_text "Other Tenant Secret"
    capture("mobile-390-page-2")
  end

  test "narrow mobile at 320 pixels has no horizontal page overflow" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 320, height: 700, deviceScaleFactor: 1, mobile: true)
    visit "/backoffice/resources/users?per_page=10"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_operator evaluate_script("document.documentElement.scrollWidth"),
      :<=, evaluate_script("window.innerWidth") + 1
    capture("mobile-320-users")
  end

  test "keyboard-accessible table sort link works with Enter" do
    visit "/backoffice/resources/users?per_page=10"
    link = find("a.rk-sort-link[aria-label='Sort by Name ascending']")
    execute_script("arguments[0].focus()", link.native)
    assert_equal "Sort by Name ascending",
      evaluate_script("document.activeElement.getAttribute('aria-label')")
    link.send_keys(:enter)
    assert_selector "table.rk-index-table th[aria-sort='ascending']"
    assert_selector "a.rk-sort-link[aria-label='Sort by Name descending']"
  end

  test "cursor pagination navigates in Chrome and header sorting resets cursor" do
    visit "/backoffice/resources/cursor_users?per_page=10&sort=name"
    assert_selector "table.rk-index-table tbody tr", count: 10
    click_link "Next"
    assert_selector "nav[aria-label='Pagination'] a", text: "Previous"
    assert_includes current_url, "cursor="
    find("a[aria-label='Sort by Email ascending']").click
    assert_selector "th[aria-sort='ascending'] a.rk-sort-link"
    refute_includes current_url, "cursor="
    assert_selector "table.rk-index-table tbody tr", count: 10
    capture("desktop-keyset")
  end

  test "forms and pagination still work when JavaScript execution is disabled" do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled",
      value: true)
    visit "/backoffice/resources/users?per_page=10"
    assert_selector "table.rk-index-table tbody tr", count: 10
    find("details.rk-index-advanced summary").click
    find("select[name='filters[role]']").select("admin")
    within("form[data-rk-index-form]") { click_button "Apply" }
    assert_selector "a.rk-index-filter-chip"
    assert_selector "table.rk-index-table tbody tr"
    find("a[aria-label='Remove Role filter']").click
    assert_no_selector "a.rk-index-filter-chip"
    click_link "Next"
    assert_text "Page 2"
    assert_selector "table.rk-index-table tbody tr", count: 10
  end

  private

  def capture(name)
    directory = Rails.root.join("tmp", "screenshots", "index-acceptance")
    FileUtils.mkdir_p(directory)
    page.save_screenshot(directory.join("#{name}.png").to_s)
  end
end
