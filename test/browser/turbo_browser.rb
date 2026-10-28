# frozen_string_literal: true

require_relative "../test_helper"
require "action_dispatch/system_test_case"
require "base64"

class TurboBrowserAcceptanceTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 900]

  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "turbo-acceptance-only"
    @tenant = Organization.create!(name: "Turbo tenant", slug: "acme")
    23.times do |n|
      User.create!(organization: @tenant, name: "Turbo User #{n}",
        email: "turbo-#{n}@example.test", status: "active", role: "member")
    end
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setExtraHTTPHeaders",
      headers: { "Authorization" =>
        "Basic #{Base64.strict_encode64('acme:turbo-acceptance-only')}" })
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous_password
  end

  test "real Turbo Drive visit, pagination and browser history preserve index" do
    visit "/backoffice/resources/users?per_page=10"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_equal true, evaluate_script("Boolean(window.Turbo)")
    assert_equal true, evaluate_script("window.Turbo.session.drive")
    assert_equal true, evaluate_script("Boolean(window.Stimulus)")
    execute_script("document.querySelector('main').setAttribute('data-controller', 'rekorra-probe')")
    assert_selector "main[data-rk-probe-connected='true']"
    execute_script("window.__rekorraTurboCount = 0; document.addEventListener('turbo:load', () => window.__rekorraTurboCount++)")

    click_link "Next"
    assert_text "Page 2"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_operator evaluate_script("window.__rekorraTurboCount"), :>=, 1

    page.go_back
    assert_text "Page 1"
    assert_selector "table.rk-index-table tbody tr", count: 10
    assert_operator evaluate_script("window.__rekorraTurboCount"), :>=, 2
    assert_nil evaluate_script("document.querySelector('[data-rk-index]').dataset.loading")
  end
end
