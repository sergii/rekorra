# frozen_string_literal: true

require_relative "test_helper"

class ContextReferencesTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @order = Order.create!(customer: @alice, number: "ACME-CONTEXT",
      status: "paid", total_cents: 10_000, support_issue_id: "10024",
      support_issue_key: "BILL-482", trace_id: "4bf92f3577b34da6a3ce929d0e0e4736")
    @foreign = Order.create!(customer: @bob, number: "GLOBEX-CONTEXT",
      status: "pending", total_cents: 400,
      support_issue_id: "10025", support_issue_key: "BILL-483", trace_id: "abc123")
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous_password }

  def headers(tenant = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(tenant, "test-password") }
  end

  test "Order links to authorized Customer and Organization resources" do
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-context a[href='/backoffice/resources/customers/#{@alice.id}']", text: "Customer: Alice"
    assert_select "section.rk-context a[href='/backoffice/resources/organizations/#{@acme.id}']", text: "Organization: Acme"
    assert_includes response.body, "Jira issue: BILL-482"
    assert_includes response.body, "Datadog trace: 4bf92f3577b34da6a3ce929d0e0e4736"
  end

  test "external references are policy checked separately from record visibility" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers("globex")
    assert_response :success
    assert_includes response.body, "Jira issue: BILL-483"
    assert_not_includes response.body, "Datadog trace: abc123"
    assert_select "section.rk-context a[href='/backoffice/resources/customers/#{@bob.id}']"
    assert_select "section.rk-context a[href='/backoffice/resources/organizations/#{@globex.id}']"
  end

  test "cross tenant source cannot disclose context" do
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers
    assert_response :not_found
    assert_not_includes response.body, "BILL-483"
  end

  test "anonymous actor cannot disclose context" do
    get "/backoffice/resources/orders/#{@order.id}"
    assert_response :unauthorized
    assert_not_includes response.body, "BILL-482"
  end

  test "missing external IDs do not produce phantom references" do
    another = Order.create!(customer: @alice, number: "NO-REFERENCES",
      status: "pending", total_cents: 100)
    get "/backoffice/resources/orders/#{another.id}", headers: headers
    assert_response :success
    assert_select "section.rk-context .rk-context__label", count: 0
    assert_select "section.rk-context a", count: 2
  end

  test "scoped resolver will not follow a foreign tenant ID" do
    section = Rekorra::Context::Section.new
    section.record(:customer, resource: :customers, id: ->(_source) { @bob.id })
    resource = Struct.new(:context).new(section)
    entries = Rekorra::Context::Resolver.new(resource: resource,
      record: @order, actor: @acme, configuration: Rekorra.configuration,
      authorize: ->(_subject, _action) { true },
      scope: ->(model) { model.where(organization_id: @acme.id) }).call
    assert_empty entries
  end

  test "denied external reference does not evaluate ID or label callbacks" do
    invoked = false
    section = Rekorra::Context::Section.new
    section.external(:private, provider: :github_issues, instance: "sergii/rekorra",
      kind: :issue, id: ->(_record) { invoked = true; "314" },
      display_key: ->(_record) { invoked = true; "ISSUE-314" }, authorize: :private?)
    resource = Struct.new(:context).new(section)
    entries = Rekorra::Context::Resolver.new(resource: resource,
      record: @order, actor: @acme, configuration: Rekorra.configuration,
      authorize: ->(_subject, _action) { false },
      scope: ->(model) { model.none }).call
    assert_empty entries
    assert_equal false, invoked
  end

  test "ContextRef identity includes tenant application and environment" do
    args = { application: "billing", environment: "production",
      tenant: "acme", resource: "orders", id: "42" }
    a = Rekorra::ContextRef.new(**args)
    same = Rekorra::ContextRef.new(**args)
    other = Rekorra::ContextRef.new(**args.merge(tenant: "globex"))
    staging = Rekorra::ContextRef.new(**args.merge(environment: "staging"))
    assert_equal a, same
    assert_equal a.hash, same.hash
    assert_not_equal a, other
    assert_not_equal a, staging
    assert a.frozen?
    assert_raises(FrozenError) { a.id << "extra" }
  end

  test "ExternalRef handles different providers and provider-specific IDs" do
    jira = Rekorra::ExternalRef.new(provider: :jira,
      instance: "acme.atlassian.net", kind: :issue, id: "10024", display_key: "BILL-482")
    github = Rekorra::ExternalRef.new(provider: :github_issues,
      instance: "sergii/rekorra", kind: :issue, id: "314")
    trace = Rekorra::ExternalRef.new(provider: :datadog,
      instance: "us1", kind: :trace, id: "4bf92f3577b34da6a3ce929d0e0e4736")
    assert_equal "BILL-482", jira.display_key
    assert_equal "314", github.display_key
    assert_equal :trace, trace.kind
    assert_equal :github_issues, github.provider
    assert jira.frozen?

    # Changing a Jira display key does not change the remote issue identity.
    renamed = Rekorra::ExternalRef.new(provider: :jira,
      instance: "acme.atlassian.net", kind: :issue, id: "10024",
      display_key: "BILL-900")
    assert_equal jira, renamed
    assert_equal jira.hash, renamed.hash
    assert_not_equal jira.to_h, renamed.to_h
  end

  test "context resolver rejects a non-relation scope" do
    section = Rekorra::Context::Section.new
    section.record(:customer, resource: :customers, id: ->(source) { source.customer_id })
    resource = Struct.new(:context).new(section)
    resolver = Rekorra::Context::Resolver.new(resource: resource, record: @order,
      actor: @acme, configuration: Rekorra.configuration,
      authorize: ->(_subject, _action) { true },
      scope: ->(_model) { Customer.all.to_a })
    assert_raises(Rekorra::ConfigurationError) { resolver.call }
  end

  test "reference identifiers reject blanks and control characters" do
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::ContextRef.new(application: "billing", environment: "test",
        tenant: "", resource: "orders", id: "1")
    end
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::ExternalRef.new(provider: :jira, instance: "example.atlassian.net",
        kind: :issue, id: "abc\n123")
    end
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::ExternalRef.new(provider: "Bad Provider", instance: "host",
        kind: :issue, id: "1")
    end
  end

  test "context DSL rejects untrusted literal IDs and implicit external permission" do
    section = Rekorra::Context::Section.new
    assert_raises(Rekorra::ConfigurationError) do
      section.record(:customer, resource: :customers, id: "12")
    end
    assert_raises(Rekorra::ConfigurationError) do
      section.external(:issue, provider: :jira, instance: "example.atlassian.net",
        kind: :issue, id: ->(_record) { "12" }, authorize: :show)
    end
  end
end
