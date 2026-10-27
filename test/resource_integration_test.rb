# frozen_string_literal: true

require_relative "test_helper"
require "action_controller/metal/request_forgery_protection"

class ResourceIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @other = Customer.create!(organization: @globex, name: "Hidden", email: "hidden@example.test")
    @order = Order.create!(customer: @alice, number: "ACME-1", status: "paid", total_cents: 25000)
    @foreign_order = Order.create!(customer: @other, number: "GLOBEX-1", status: "paid", total_cents: 9900)
    Payment.create!(order: @order, status: "captured", amount_cents: 25000)
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous_password
  end

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def csrf_token(action = "/backoffice/resources/orders", source = "/backoffice/resources/orders/new")
    get source, headers: headers
    assert_response :success
    Nokogiri::HTML(response.body).at_css("form[action='#{action}'] input[name='authenticity_token']")["value"]
  end

  test "lists orders and related customer without leaking another organization" do
    get "/backoffice/resources/orders", headers: headers
    assert_response :success
    assert_includes response.body, "ACME-1"
    assert_includes response.body, "Alice"
    assert_not_includes response.body, "GLOBEX-1"
  end

  test "show page contains scoped payments" do
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_includes response.body, "Payments"
    assert_includes response.body, "$250.00"
  end

  test "an order from another organization is not accessible" do
    get "/backoffice/resources/orders/#{@foreign_order.id}", headers: headers
    assert_response :not_found
  end

  test "creating an order with a foreign customer is forbidden" do
    post "/backoffice/resources/orders", headers: headers, params: {
      authenticity_token: csrf_token,
      record: { number: "ACME-2", customer_id: @other.id, status: "pending", total_cents: 500 }
    }
    assert_response :forbidden
    assert_not Order.exists?(number: "ACME-2")
  end

  test "creates an order through a plain HTML form endpoint" do
    assert_difference("Order.count", 1) do
      post "/backoffice/resources/orders", headers: headers, params: {
        authenticity_token: csrf_token,
        record: { number: "ACME-2", customer_id: @alice.id, status: "pending", total_cents: 500 }
      }
    end
    assert_response :redirect
    assert_equal "ACME-2", Order.order(:id).last.number
  end

  test "custom field renderer overrides default output" do
    get "/backoffice/resources/payments", headers: headers
    assert_response :success
    assert_includes response.body, "Gateway: CAPTURED"
  end

  test "theme form works without JavaScript" do
    token = csrf_token("/backoffice/theme")
    post "/backoffice/theme", headers: headers, params: { authenticity_token: token, theme: "dark" }
    assert_response :redirect
    get "/backoffice", headers: headers
    assert_response :success
    assert_select "html[data-theme='dark']"
  end

  test "updates an order through its HTML form" do
    url = "/backoffice/resources/orders/#{@order.id}"
    token = csrf_token(url, "#{url}/edit")
    patch url, headers: headers, params: {
      authenticity_token: token, record: { status: "fulfilled", customer_id: @alice.id }
    }
    assert_response :redirect
    assert_equal "fulfilled", @order.reload.status
  end

  test "deletes an order through its HTML form" do
    disposable = Order.create!(customer: @alice, number: "ACME-DELETE", status: "pending", total_cents: 0)
    url = "/backoffice/resources/orders/#{disposable.id}"
    token = csrf_token(url, url)
    assert_difference("Order.count", -1) do
      delete url, headers: headers, params: { authenticity_token: token }
    end
    assert_response :see_other
  end

  test "invalid CSRF requests are rejected" do
    get "/backoffice/resources/orders/new", headers: headers
    assert_response :success
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/backoffice/resources/orders", headers: headers, params: {
        record: { number: "FORGED", customer_id: @alice.id, status: "pending", total_cents: 1 }
      }
    end
    assert_not Order.exists?(number: "FORGED")
  end

  test "Propshaft serves the engine CSS asset" do
    get "/backoffice", headers: headers
    assert_response :success
    stylesheet = Nokogiri::HTML(response.body).at_css("link[rel='stylesheet']")["href"]
    assert_match(%r{/assets/rekorra/application-[a-f0-9]+\.css}, stylesheet)
    get stylesheet
    assert_response :success
    assert_includes response.body, ".rk-app"
  end

  test "search and sort are restricted to configured fields" do
    get "/backoffice/resources/orders", headers: headers,
      params: { q: "ACME", sort: "nonexistent_sql", direction: "desc" }
    assert_response :success
    assert_includes response.body, "ACME-1"
  end

  test "index uses a bounded number of SQL selects for related records" do
    10.times { |n| Order.create!(customer: @alice, number: "ACME-#{n + 20}", status: "pending", total_cents: 100) }
    selects = []
    handler = ->(*args) do
      payload = args.last
      selects << payload[:sql] if payload[:sql].to_s.match?(/\ASELECT\b/i) && !payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(handler, "sql.active_record") do
      get "/backoffice/resources/orders", headers: headers
    end
    assert_response :success
    assert_operator selects.length, :<=, 8
  end
end
