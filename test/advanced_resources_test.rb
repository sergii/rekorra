# frozen_string_literal: true

require_relative "test_helper"

class AdvancedResourcesTest < ActionDispatch::IntegrationTest
  setup do
    @original_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@advanced.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@advanced.test")
    @ticket = Ticket.create!(customer: @alice, number: "ACME-ADVANCED", status: "pending", estimated_minutes: 4321)
    @globex_ticket = Ticket.create!(customer: @bob, number: "GLOBEX-ADVANCED", status: "pending", estimated_minutes: 9898)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @original_password }

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def csrf_token(url, page)
    get page, headers: headers("globex")
    assert_response :success
    Nokogiri::HTML(response.body).at_css("form[action='#{url}'] input[name='authenticity_token']")["value"]
  end

  test "field policy excludes private columns from index and show for restricted tenant" do
    get "/backoffice/resources/tickets", headers: headers("globex")
    assert_response :success
    assert_includes response.body, "GLOBEX-ADVANCED"
    assert_select "table.rk-index-table th", text: "Estimated minutes", count: 0
    assert_select "input[name='filters[estimated_minutes_min]']", count: 0
    assert_select "input[name='filters[estimated_minutes_max]']", count: 0
    assert_select "select[name='sort'] option[value='estimated_minutes']", count: 0
    assert_select "table.rk-index-table td[data-label='Estimated minutes']", count: 0

    get "/backoffice/resources/tickets/#{@globex_ticket.id}", headers: headers("globex")
    assert_response :success
    assert_select "dl.rk-details dt", text: "Estimated minutes", count: 0
    assert_not_includes response.body, "9898"
  end

  test "authorized tenant keeps total field across index show and form" do
    get "/backoffice/resources/tickets", headers: headers
    assert_response :success
    assert_select "table.rk-index-table th", minimum: 1
    assert Nokogiri::HTML(response.body).css("table.rk-index-table th").any? { |th| th.text.include?("Estimated minutes") }
    assert_select "input[name='filters[estimated_minutes_min]']", count: 1

    get "/backoffice/resources/tickets/#{@ticket.id}", headers: headers
    assert_response :success
    assert_select "dl.rk-details dt", text: "Estimated minutes", count: 1

    get "/backoffice/resources/tickets/#{@ticket.id}/edit", headers: headers
    assert_response :success
    assert_select "input[name='record[estimated_minutes]']", count: 1
  end

  test "restricted tenant cannot use private column sort or filter as an oracle" do
    get "/backoffice/resources/tickets", headers: headers("globex"),
      params: { sort: "estimated_minutes" }
    assert_response :forbidden

    get "/backoffice/resources/tickets", headers: headers("globex"),
      params: { filters: { estimated_minutes_min: "1" } }
    assert_response :forbidden
  end

  test "restricted tenant cannot overwrite private field with forged PATCH" do
    url = "/backoffice/resources/tickets/#{@globex_ticket.id}"
    token = csrf_token(url, "#{url}/edit")
    assert_select "input[name='record[estimated_minutes]']", count: 0
    patch url, headers: headers("globex"),
      params: { authenticity_token: token, record: { status: "completed", estimated_minutes: "1" } }
    assert_response :forbidden
    assert_equal 9898, @globex_ticket.reload.estimated_minutes
    assert_equal "pending", @globex_ticket.status
  end

  test "restricted tenant cannot mass-assign private field during CREATE" do
    url = "/backoffice/resources/tickets"
    token = csrf_token(url, "#{url}/new")
    assert_select "input[name='record[estimated_minutes]']", count: 0
    assert_no_difference("Ticket.count") do
      post url, headers: headers("globex"), params: {
        authenticity_token: token,
        record: { number: "FORGED-ADVANCED", customer_id: @bob.id,
          status: "pending", estimated_minutes: 999_999 }
      }
    end
    assert_response :forbidden
  end

  test "restricted tenant can still update fields not protected by field policy" do
    url = "/backoffice/resources/tickets/#{@globex_ticket.id}"
    token = csrf_token(url, "#{url}/edit")
    patch url, headers: headers("globex"),
      params: { authenticity_token: token, record: { status: "resolved" } }
    assert_response :redirect
    assert_equal "resolved", @globex_ticket.reload.status
    assert_equal 9898, @globex_ticket.estimated_minutes
  end

  test "association options are limited and searchable inside current tenant" do
    125.times do |n|
      Customer.create!(organization: @acme,
        name: "Customer #{n.to_s.rjust(3, '0')}",
        email: "customer-#{n}@advanced.test")
    end
    Customer.create!(organization: @globex,
      name: "Customer 120 Foreign", email: "foreign-120@advanced.test")

    get "/backoffice/resources/tickets/new", headers: headers
    assert_response :success
    assert_select "select[name='record[customer_id]'] option", maximum: 51
    assert_select "input[name='association_q[customer_id]']", count: 1

    get "/backoffice/resources/tickets/new", headers: headers,
      params: { association_q: { customer_id: "Customer 120" } }
    assert_response :success
    options = Nokogiri::HTML(response.body).css("select[name='record[customer_id]'] option")
    assert options.any? { |o| o.text == "Customer 120" }
    assert options.none? { |o| o.text == "Customer 120 Foreign" }
  end

  test "editing keeps currently selected belongs_to record outside first 50 choices" do
    120.times do |n|
      Customer.create!(organization: @acme, name: "Other #{n.to_s.rjust(3, '0')}",
        email: "other-#{n}@advanced.test")
    end
    target = Customer.create!(organization: @acme, name: "Very Late Customer",
      email: "late@advanced.test")
    @ticket.update!(customer: target)
    url = "/backoffice/resources/tickets/#{@ticket.id}/edit"
    get url, headers: headers
    assert_response :success
    select = Nokogiri::HTML(response.body).at_css("select[name='record[customer_id]']")
    assert select
    assert_operator select.css("option").length, :<=, 52
    assert select.css("option").any? { |o| o["value"] == target.id.to_s }
    assert_equal target.id.to_s, select.at_css("option[selected]")["value"]
  end

  test "association search escapes wildcard characters and rejects unrelated foreign IDs" do
    special = Customer.create!(organization: @acme, name: "Customer 10%",
      email: "pct@advanced.test")
    Customer.create!(organization: @acme, name: "Customer 1000",
      email: "no-pct@advanced.test")
    get "/backoffice/resources/tickets/new", headers: headers,
      params: { association_q: { customer_id: "10%" } }
    assert_response :success
    options = Nokogiri::HTML(response.body).css("select[name='record[customer_id]'] option")
    assert options.any? { |o| o["value"] == special.id.to_s }
    assert options.none? { |o| o.text == "Customer 1000" }

    get "/backoffice/resources/tickets/new", headers: headers
    token = Nokogiri::HTML(response.body).at_css("form[action='/backoffice/resources/tickets'] input[name='authenticity_token']")["value"]
    post "/backoffice/resources/tickets", headers: headers, params: {
      authenticity_token: token,
      record: { number: "FORGED-FK", customer_id: @bob.id, status: "pending", estimated_minutes: 1 }
    }
    assert_response :forbidden
    assert_not Ticket.exists?(number: "FORGED-FK")
  end

  test "field policy DSL rejects invalid or repeated configurations" do
    klass = Class.new(Rekorra::Resource) { model "Ticket" }
    klass.field_policy(:estimated_minutes, read: :view_totals?, write: :edit_totals?)
    assert_equal :view_totals?, klass.policy_for(:estimated_minutes, :read)
    assert_raises(Rekorra::ConfigurationError) { klass.field_policy(:estimated_minutes, read: :other?) }
    assert_raises(Rekorra::ConfigurationError) { klass.field_policy(:number, read: :unsafe) }
    klass.field_policy(:missing_column, read: :read_missing?)
    assert_raises(Rekorra::ConfigurationError) { klass.validate! }
  end
end
