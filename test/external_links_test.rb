# frozen_string_literal: true

require_relative "test_helper"
require "uri"
require "cgi"

class ExternalLinksTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @order = Order.create!(customer: @alice, number: "A-100", status: "paid", total_cents: 1000)
    @foreign = Order.create!(customer: @bob, number: "B-200", status: "paid", total_cents: 1000)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous_password }

  def headers(organization = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(organization, "test-password") }
  end

  test "show page renders authorized provider URLs as safe external links" do
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    anchors = Nokogiri::HTML(response.body).css("a.rk-external-link")
    assert_equal ["See logs", "Find related issues"], anchors.map(&:text)

    links = anchors.to_h { |anchor| [anchor.text, anchor] }
    logs = links.fetch("See logs")
    uri = URI.parse(logs["href"])
    assert_equal "https", uri.scheme
    assert_equal "service.sumologic.com", uri.host
    assert_equal "/log-search/create", uri.path
    query = CGI.parse(uri.query)
    assert_equal ["-24h"], query.fetch("startTime")
    assert_equal ["now"], query.fetch("endTime")
    assert_includes query.fetch("query").first, "order_id=#{@order.id}"
    assert_includes query.fetch("query").first, "tenant_id=#{@acme.id}"

    issues = URI.parse(links.fetch("Find related issues")["href"])
    assert_equal "github.com", issues.host
    assert_equal "/sergii/rekorra/issues", issues.path
    assert_equal ["order_id:#{@order.id}"], CGI.parse(issues.query).fetch("q")

    anchors.each do |anchor|
      assert_equal "_blank", anchor["target"]
      assert_includes anchor["rel"], "noopener"
      assert_includes anchor["rel"], "noreferrer"
      assert_equal "no-referrer", anchor["referrerpolicy"]
    end
  end

  test "external link policies hide forbidden providers" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers("globex")
    assert_response :success
    assert_select "a.rk-external-link", text: "See logs", count: 0
    assert_select "a.rk-external-link", text: "Find related issues", count: 1
  end

  test "a cross-tenant record cannot expose links" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers
    assert_response :not_found
    assert_not_includes response.body, "See logs"
  end

  test "anonymous requests cannot expose links" do
    get "/backoffice/resources/orders/#{@order.id}"
    assert_response :unauthorized
    assert_not_includes response.body, "See logs"
  end

  test "resolver cannot create an off-allowlist URL" do
    definition = Rekorra::ExternalLink.new(:unsafe, label: "Unsafe", provider: :url,
      authorize: :show?, base_url: "https://evil.example", path: "/orders")
    assert_raises(Rekorra::ConfigurationError) { resolve(definition) }
  end

  test "resolver rejects insecure or credentialed URLs" do
    %w[http://github.com https://user:secret@github.com javascript:alert(1)].each do |base_url|
      definition = Rekorra::ExternalLink.new(:unsafe, label: "Unsafe", provider: :url,
        authorize: :show?, base_url: base_url, path: "/issues")
      assert_raises(Rekorra::ConfigurationError) { resolve(definition) }
    end
  end

  test "resolver rejects scheme-relative paths and nested params" do
    invalid_path = Rekorra::ExternalLink.new(:unsafe, label: "Unsafe", provider: :url,
      authorize: :show?, base_url: "https://github.com", path: "//evil.example")
    assert_raises(Rekorra::ConfigurationError) { resolve(invalid_path) }

    invalid_params = Rekorra::ExternalLink.new(:unsafe, label: "Unsafe", provider: :url,
      authorize: :show?, base_url: "https://github.com", path: "/issues",
      params: { q: { raw: "nested" } })
    assert_raises(Rekorra::ConfigurationError) { resolve(invalid_params) }
  end

  test "query params are encoded, not appended unescaped" do
    definition = Rekorra::ExternalLink.new(:search, label: "Search", provider: :url,
      authorize: :show?, base_url: "https://github.com", path: "/issues",
      params: ->(_record) { { q: 'status:"error" & order=42' } })
    result = resolve(definition).first
    assert_equal ['status:"error" & order=42'], CGI.parse(URI(result.url).query).fetch("q")
    assert_includes result.url, "%26"
  end

  test "denied links do not evaluate record-derived callbacks" do
    invoked = false
    definition = Rekorra::ExternalLink.new(:private, label: "Private", provider: :url,
      authorize: :private?, base_url: "https://github.com", path: "/issues",
      params: ->(_record) { invoked = true; { q: "private" } })
    assert_empty resolve(definition, allow: false)
    assert_equal false, invoked
  end

  test "unconfigured provider stays hidden" do
    definition = Rekorra::ExternalLink.new(:logs, label: "See logs", provider: :sumo_logic,
      authorize: :show?, query: "order_id:42")
    configuration = Rekorra::Configuration.new
    configuration.external_link_allowed_hosts = ["service.sumologic.com"]
    assert_empty resolve(definition, configuration: configuration)
  end

  private

  def resolve(definition, allow: true, configuration: Rekorra.configuration)
    resource = Struct.new(:external_links).new([definition])
    Rekorra::ExternalLinks::Resolver.new(resource: resource, record: @order,
      configuration: configuration, authorize: ->(_record, _action) { allow }).call
  end
end
