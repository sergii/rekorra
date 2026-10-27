# frozen_string_literal: true

require_relative "test_helper"

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
      record: { number: "ACME-2", customer_id: @other.id, status: "pending", total_cents: 500 }
    }
    assert_response :forbidden
    assert_not Order.exists?(number: "ACME-2")
  end

  test "creates an order through a plain HTML form endpoint" do
    assert_difference("Order.count", 1) do
      post "/backoffice/resources/orders", headers: headers, params: {
        record: { number: "ACME-2", customer_id: @alice.id, status: "pending", total_cents: 500 }
      }
    end
    assert_response :redirect
    assert_equal "ACME-2", Order.order(:id).last.number
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
