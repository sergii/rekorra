# frozen_string_literal: true

require_relative "test_helper"

class FindingsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @ticket = Ticket.create!(customer: @alice, number: "ACME-FIND", status: "pending", estimated_minutes: 1200)
    @foreign = Ticket.create!(customer: @bob, number: "GLOBEX-FIND", status: "pending", estimated_minutes: 1600)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @password }

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def show(ticket = @ticket, slug: "acme")
    get "/backoffice/resources/tickets/#{ticket.id}", headers: headers(slug)
  end

  def capture(ticket, minutes)
    Interaction.create!(ticket: ticket, status: "logged", duration_minutes: minutes)
  end

  test "logged interaction and pending Ticket produces a structured finding" do
    capture(@ticket, 1000)
    capture(@ticket, 200)
    show
    assert_response :success
    assert_select "section.rk-findings li.rk-findings__item", count: 1
    assert_select "section.rk-findings strong", text: "Interaction logged, ticket still pending"
    assert_select "section.rk-findings .rk-badge", text: "Warning"
    assert_includes response.body, "Logged (minutes)"
    assert_includes response.body, "1200"
  end

  test "no interaction, partial interaction, wrong interaction status and advanced ticket are clear" do
    show
    assert_response :success
    assert_select "section.rk-findings li.rk-findings__item", count: 0

    capture(@ticket, 1199)
    show
    assert_select "section.rk-findings li.rk-findings__item", count: 0

    Interaction.create!(ticket: @ticket, status: "authorized", duration_minutes: 5000)
    show
    assert_select "section.rk-findings li.rk-findings__item", count: 0

    capture(@ticket, 1)
    @ticket.update!(status: "completed")
    show
    assert_select "section.rk-findings li.rk-findings__item", count: 0
  end

  test "zero-total tickets are ignored" do
    @ticket.update!(estimated_minutes: 0)
    show
    assert_response :success
    assert_select "section.rk-findings li.rk-findings__item", count: 0
  end

  test "view_findings is a separate tenant-aware policy" do
    capture(@foreign, 1600)
    show(@foreign, slug: "globex")
    assert_response :success
    assert_select "section.rk-findings", count: 0
    assert_not_includes response.body, "Logged (minutes)"

    show(@foreign)
    assert_response :not_found
    assert_not_includes response.body, "Interaction logged, ticket still pending"
  end

  test "anonymous requests cannot see evidence" do
    capture(@ticket, 1200)
    get "/backoffice/resources/tickets/#{@ticket.id}"
    assert_response :unauthorized
    assert_not_includes response.body, "Logged (minutes)"
  end

  test "resolver skips rule without policy and does not invoke it" do
    invoked = false
    rule = Object.new
    rule.define_singleton_method(:evaluate) { |record:| invoked = true; nil }
    registry = Rekorra::Findings::Registry.new
    registry.register(:logged_but_pending, rule)
    findings = Rekorra::Findings::Resolver.new(
      resource: TicketResource, record: @ticket, registry: registry,
      authorize: ->(_record, _action) { false }
    ).call
    assert_empty findings
    assert_equal false, invoked
  end

  test "a second independent rule is used with the same generic resolver" do
    other = Object.new
    other.define_singleton_method(:evaluate) do |record:|
      Rekorra::Findings::Finding.new(code: "manual_review", severity: "info",
        title: "Manual review requested", description: "Check record with support.",
        evidence: [
          Rekorra::Findings::Evidence.new(label: "Record ID", value: record.id.to_s)
        ])
    end
    registry = Rekorra::Findings::Registry.new
    registry.register(:manual_review, other)
    definition = Rekorra::Findings::Definition.new
    definition.rule :manual_review
    definition.authorize :view_findings?
    definition.limit 10
    definition.validate!
    resource = Struct.new(:findings).new(definition)
    results = Rekorra::Findings::Resolver.new(resource: resource, record: @ticket,
      authorize: ->(_record, _action) { true }, registry: registry).call
    assert_equal ["manual_review"], results.map(&:code)
    assert_equal "info", results.first.severity
    assert_equal @ticket.id.to_s, results.first.evidence.first.value
  end

  test "invalid findings and evidence are rejected" do
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::Findings::Finding.new(code: "invalid", severity: "fatal",
        title: "Bad", description: "Unexpected", evidence: [])
    end
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::Findings::Evidence.new(label: "secret", value: "one\nanother")
    end
  end

  test "invalid rule output is rejected" do
    rule = Object.new
    rule.define_singleton_method(:evaluate) { |record:| "secret" }
    registry = Rekorra::Findings::Registry.new
    registry.register(:logged_but_pending, rule)
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::Findings::Resolver.new(resource: TicketResource, record: @ticket,
        authorize: ->(_record, _action) { true }, registry: registry).call
    end
  end

  test "finding configuration is explicit and bounded" do
    definition = Rekorra::Findings::Definition.new
    definition.rule :logged_but_pending
    definition.authorize :view_findings?
    definition.limit 1000
    assert_raises(Rekorra::ConfigurationError) { definition.validate! }
    assert_raises(Rekorra::ConfigurationError) { definition.rule :logged_but_pending }

    registry = Rekorra::Findings::Registry.new
    assert_raises(Rekorra::ConfigurationError) { registry.fetch(:missing) }
  end

  test "finding text is escaped by Rails and not executed as HTML" do
    item = Rekorra::Findings::Evidence.new(label: "Note", value: "<script>alert(1)</script>")
    finding = Rekorra::Findings::Finding.new(code: "xss", severity: "warning",
      title: "<img src=x onerror=alert(1)>",
      description: "Demo HTML escaping", evidence: [item])
    assert_equal "<script>alert(1)</script>", finding.evidence.first.value
    assert finding.frozen?
    assert_raises(FrozenError) { finding.title << "bad" }
  end

  test "Findings has no obligatory third-party gem" do
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert spec
    assert_not_includes spec.runtime_dependencies.map(&:name), "dry-monads"
  end
end
