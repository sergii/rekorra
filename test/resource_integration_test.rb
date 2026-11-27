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
    @ticket = Ticket.create!(customer: @alice, number: "ACME-1", status: "completed", estimated_minutes: 25000)
    @foreign_ticket = Ticket.create!(customer: @other, number: "GLOBEX-1", status: "completed", estimated_minutes: 9900)
    Interaction.create!(ticket: @ticket, status: "logged", duration_minutes: 25000)
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous_password
  end

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def csrf_token(action = "/backoffice/resources/tickets", source = "/backoffice/resources/tickets/new")
    get source, headers: headers
    assert_response :success
    Nokogiri::HTML(response.body).at_css("form[action='#{action}'] input[name='authenticity_token']")["value"]
  end

  test "lists tickets and related customer without leaking another organization" do
    get "/backoffice/resources/tickets", headers: headers
    assert_response :success
    assert_includes response.body, "ACME-1"
    assert_includes response.body, "Alice"
    assert_not_includes response.body, "GLOBEX-1"
  end

  test "show page contains scoped interactions" do
    get "/backoffice/resources/tickets/#{@ticket.id}", headers: headers
    assert_response :success
    assert_includes response.body, "Interactions"
    assert_includes response.body, "25000"
  end

  test "an ticket from another organization is not accessible" do
    get "/backoffice/resources/tickets/#{@foreign_ticket.id}", headers: headers
    assert_response :not_found
  end

  test "creating an ticket with a foreign customer is forbidden" do
    post "/backoffice/resources/tickets", headers: headers, params: {
      authenticity_token: csrf_token,
      record: { number: "ACME-2", customer_id: @other.id, status: "pending", estimated_minutes: 500 }
    }
    assert_response :forbidden
    assert_not Ticket.exists?(number: "ACME-2")
  end

  test "creates an ticket through a plain HTML form endpoint" do
    assert_difference("Ticket.count", 1) do
      post "/backoffice/resources/tickets", headers: headers, params: {
        authenticity_token: csrf_token,
        record: { number: "ACME-2", customer_id: @alice.id, status: "pending", estimated_minutes: 500 }
      }
    end
    assert_response :redirect
    assert_equal "ACME-2", Ticket.order(:id).last.number
  end

  test "custom field renderer overrides default output" do
    get "/backoffice/resources/interactions", headers: headers
    assert_response :success
    assert_includes response.body, "Channel: LOGGED"
  end

  test "theme form works without JavaScript" do
    token = csrf_token("/backoffice/theme")
    post "/backoffice/theme", headers: headers, params: { authenticity_token: token, theme: "dark" }
    assert_response :redirect
    get "/backoffice", headers: headers
    assert_response :success
    assert_select "html[data-theme='dark']"
  end

  test "updates an ticket through its HTML form" do
    url = "/backoffice/resources/tickets/#{@ticket.id}"
    token = csrf_token(url, "#{url}/edit")
    patch url, headers: headers, params: {
      authenticity_token: token, record: { status: "resolved", customer_id: @alice.id }
    }
    assert_response :redirect
    assert_equal "resolved", @ticket.reload.status
  end

  test "deletes an ticket through its HTML form" do
    disposable = Ticket.create!(customer: @alice, number: "ACME-DELETE", status: "pending", estimated_minutes: 0)
    url = "/backoffice/resources/tickets/#{disposable.id}"
    token = csrf_token(url, url)
    assert_difference("Ticket.count", -1) do
      delete url, headers: headers, params: { authenticity_token: token }
    end
    assert_response :see_other
  end

  test "invalid CSRF requests are rejected" do
    get "/backoffice/resources/tickets/new", headers: headers
    assert_response :success
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/backoffice/resources/tickets", headers: headers, params: {
        record: { number: "FORGED", customer_id: @alice.id, status: "pending", estimated_minutes: 1 }
      }
    end
    assert_not Ticket.exists?(number: "FORGED")
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
    get "/backoffice/resources/tickets", headers: headers,
      params: { q: "ACME", sort: "nonexistent_sql", direction: "desc" }
    assert_response :success
    assert_includes response.body, "ACME-1"
  end

  test "index uses a bounded number of SQL selects for related records" do
    10.times { |n| Ticket.create!(customer: @alice, number: "ACME-#{n + 20}", status: "pending", estimated_minutes: 100) }
    selects = []
    handler = ->(*args) do
      payload = args.last
      selects << payload[:sql] if payload[:sql].to_s.match?(/\ASELECT\b/i) && !payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(handler, "sql.active_record") do
      get "/backoffice/resources/tickets", headers: headers
    end
    assert_response :success
    assert_operator selects.length, :<=, 8
  end
end
