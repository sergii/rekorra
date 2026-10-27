# frozen_string_literal: true

require_relative "test_helper"

class ActivityIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @old_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @order = Order.create!(customer: @alice, number: "ACME-ACTIVITY", status: "pending", total_cents: 900)
    @foreign = Order.create!(customer: @bob, number: "GLOBEX-ACTIVITY", status: "pending", total_cents: 800)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @old_password }

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def token_for(url, source)
    get source, headers: headers
    assert_response :success
    Nokogiri::HTML(response.body).at_css("form[action='#{url}'] input[name='authenticity_token']")["value"]
  end

  test "show displays versioned creates and whitelisted field changes" do
    @order.update!(status: "paid", total_cents: 1000, support_issue_id: "private-external-id")
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    timeline = Nokogiri::HTML(response.body).at_css("section.rk-activity")
    assert timeline
    text = timeline.text
    assert_includes text, "Activity"
    assert_includes text, "Create"
    assert_includes text, "Update"
    assert_includes text, "Status"
    assert_includes text, "pending"
    assert_includes text, "paid"
    assert_includes text, "Total cents"
    assert_not_includes text, "private-external-id"
    assert_not_includes text, "support_issue_id"
  end

  test "view activity needs a distinct policy" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers("globex")
    assert_response :success
    assert_select "section.rk-activity", count: 0
    assert_select "section.rk-context"
  end

  test "cross tenant activity cannot be read" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers
    assert_response :not_found
    assert_not_includes response.body, "Activity"
  end

  test "unauthenticated clients cannot view activity" do
    get "/backoffice/resources/orders/#{@order.id}"
    assert_response :unauthorized
  end

  test "web edit attributes the version to host actor" do
    url = "/backoffice/resources/orders/#{@order.id}"
    csrf = token_for(url, "#{url}/edit")
    patch url, headers: headers, params: {
      authenticity_token: csrf,
      record: { status: "fulfilled", customer_id: @alice.id }
    }
    assert_response :redirect
    assert_equal "demo-organization:acme", @order.versions.order(:id).last.whodunnit

    get url, headers: headers
    assert_response :success
    timeline = Nokogiri::HTML(response.body).at_css("section.rk-activity").text
    assert_includes timeline, "demo-organization:acme"
    assert_includes timeline, "fulfilled"
  end

  test "web create attributes new version to host actor" do
    url = "/backoffice/resources/orders"
    csrf = token_for(url, "#{url}/new")
    post url, headers: headers, params: {
      authenticity_token: csrf,
      record: { number: "ACME-NEW", customer_id: @alice.id, status: "pending", total_cents: 42 }
    }
    assert_response :redirect
    created = Order.find_by!(number: "ACME-NEW")
    assert_equal "demo-organization:acme", created.versions.order(:id).last.whodunnit
  end

  test "only ten latest versions are rendered by default configuration" do
    13.times { |n| @order.update!(status: "phase-#{n}") }
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-activity li.rk-activity__event", count: 10
    assert_not_includes Nokogiri::HTML(response.body).at_css("section.rk-activity").text, "phase-0"
  end

  test "timeline escapes untrusted data instead of rendering HTML" do
    @order.update!(status: "<script>alert('x')</script>")
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-activity script", count: 0
    assert_includes Nokogiri::HTML(response.body).at_css("section.rk-activity").text, "<script>"
  end

  test "activity definition validates source fields policies and limit" do
    definition = Rekorra::Activity::Definition.new
    definition.source :paper_trail
    definition.fields :no_such_column
    definition.authorize :view_activity?
    assert_raises(Rekorra::ConfigurationError) { definition.validate!(Order) }

    definition.fields :status
    definition.limit 500
    assert_raises(Rekorra::ConfigurationError) { definition.validate!(Order) }
  end

  test "resolver does not query denied activity" do
    invoked = false
    adapter = Object.new
    adapter.define_singleton_method(:events) { |**_args| invoked = true; [] }
    adapter.define_singleton_method(:with_actor) { |**_args, &block| block.call }
    registry = Rekorra::Activity::Registry.new
    registry.register(:paper_trail, adapter)
    result = Rekorra::Activity::Resolver.new(
      resource: OrderResource, record: @order, registry: registry,
      authorize: ->(_record, _policy) { false }
    ).call
    assert_empty result
    assert_equal false, invoked
  end

  test "activity sources are explicitly registered" do
    registry = Rekorra::Activity::Registry.new
    assert_raises(Rekorra::ConfigurationError) { registry.fetch(:paper_trail) }
  end

  test "Rekorra gem does not require PaperTrail" do
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert spec
    assert_not_includes spec.runtime_dependencies.map(&:name), "paper_trail"
  end
end
