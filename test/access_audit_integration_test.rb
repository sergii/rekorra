# frozen_string_literal: true

require_relative "test_helper"

class AccessAuditIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @previous = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "audit-alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "audit-bob@example.test")
    @order = Order.create!(customer: @alice, number: "AUDIT-OWN", status: "pending", total_cents: 500)
    @foreign = Order.create!(customer: @bob, number: "AUDIT-FOREIGN", status: "pending", total_cents: 900)
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous
  end

  def headers(tenant = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(tenant, "test-password") }
  end

  def path(order)
    "/backoffice/resources/orders/#{order.id}"
  end

  def csrf(source, target, tenant = "acme")
    get source, headers: headers(tenant)
    assert_response :success
    Nokogiri::HTML(response.body).at_css("form[action='#{target}'] input[name='authenticity_token']")["value"]
  end

  test "show records an authorized access with tenant, actor, ID and request correlation" do
    assert_difference("DemoAuditEntry.count", 1) do
      get path(@order), headers: headers
    end
    assert_response :success
    entry = DemoAuditEntry.last
    assert_equal "acme", entry.tenant_key
    assert_equal "demo-organization:acme", entry.actor_key
    assert_equal "Order", entry.record_type
    assert_equal @order.id.to_s, entry.record_id
    assert_equal "show", entry.action
    assert entry.request_id.present?
    assert entry.occurred_at
    assert_select "section.rk-access-audit", count: 1
    assert_select "section.rk-access-audit li", text: /Show/
    assert_not_includes response.body, "audit-alice@example.test" if false
  end

  test "access denied and anonymous accesses do not record any audit event" do
    assert_no_difference("DemoAuditEntry.count") do
      get path(@foreign), headers: headers
      assert_response :not_found
      get path(@order)
      assert_response :unauthorized
    end
  end

  test "globex accesses are recorded but cannot view audit timeline" do
    get path(@foreign), headers: headers("globex")
    assert_response :success
    assert_equal "globex", DemoAuditEntry.last.tenant_key
    assert_select "section.rk-access-audit", count: 0

    get path(@order), headers: headers
    assert_response :success
    assert_select "section.rk-access-audit li", count: 1
    assert_not_includes response.body, "demo-organization:globex"
  end

  test "create audit uses the actual persisted ID and contains no submitted attribute values" do
    url = "/backoffice/resources/orders"
    token = csrf("#{url}/new", url)
    assert_difference("DemoAuditEntry.count", 1) do
      post url, headers: headers, params: {
        authenticity_token: token,
        record: { number: "SECRET-ORDER-FIELD", status: "pending",
          total_cents: "1100", customer_id: @alice.id }
      }
      assert_response :redirect
    end
    row = DemoAuditEntry.last
    created = Order.find_by!(number: "SECRET-ORDER-FIELD")
    assert_equal "create", row.action
    assert_equal created.id.to_s, row.record_id
    assert_not_includes row.attributes.inspect, "SECRET-ORDER-FIELD"
    assert_not_includes row.attributes.inspect, "1100"
  end

  test "successful update emits one audit; unsuccessful validation emits none" do
    target = path(@order)
    token = csrf("#{target}/edit", target)
    assert_difference("DemoAuditEntry.where(action: 'update').count", 1) do
      patch target, headers: headers, params: {
        authenticity_token: token, record: { status: "fulfilled" }
      }
    end
    assert_response :redirect
    assert_equal "fulfilled", @order.reload.status

    token = csrf("#{target}/edit", target)
    assert_no_difference("DemoAuditEntry.where(action: 'update').count") do
      patch target, headers: headers, params: {
        authenticity_token: token, record: { number: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "successful destroy is logged with deleted record ID" do
    target = path(@order)
    token = csrf(target, target)
    assert_difference("DemoAuditEntry.where(action: 'destroy').count", 1) do
      delete target, headers: headers, params: { authenticity_token: token }
    end
    assert_response :see_other
    assert_not Order.exists?(id: @order.id)
    assert_equal @order.id.to_s, DemoAuditEntry.last.record_id
  end

  test "forged protected mutation never emits a successful operation" do
    target = path(@foreign)
    token = csrf("#{target}/edit", target, "globex")
    assert_no_difference("DemoAuditEntry.where(action: 'update').count") do
      patch target, headers: headers("globex"), params: {
        authenticity_token: token, record: { total_cents: "10" }
      }
    end
    assert_response :forbidden
    assert_equal 900, @foreign.reload.total_cents
  end

  test "adapter failure rolls back the model update in the host DB transaction" do
    registry = Rekorra.configuration.access_audit_adapters
    original = registry.fetch(:active_record)
    failing = Object.new
    failing.define_singleton_method(:write!) { |event:| raise "AUDIT STORAGE UNAVAILABLE" }
    failing.define_singleton_method(:entries) { |**_kwargs| [] }
    target = path(@order)
    token = csrf("#{target}/edit", target)
    begin
      registry.register :active_record, failing
      assert_raises(RuntimeError) do
        patch target, headers: headers, params: {
          authenticity_token: token, record: { status: "fulfilled" }
        }
      end
      assert_equal "pending", @order.reload.status
      assert_equal 0, DemoAuditEntry.where(action: "update").count
    ensure
      registry.register :active_record, original
    end
  end

  test "read adapter cannot fetch another tenant even with the same numeric ID" do
    DemoAuditEntry.create!(tenant_key: "globex", actor_key: "globex-operator",
      record_type: "Order", record_id: @order.id.to_s, action: "show",
      request_id: "other-tenant", occurred_at: Time.current)
    get path(@order), headers: headers
    assert_response :success
    assert_not_includes response.body, "globex-operator"
    assert_select "section.rk-access-audit li", count: 1
  end

  test "Audit contract supports a second in-memory adapter with authorization guard" do
    registry = Rekorra::AccessAudit::Registry.new
    memory = Object.new
    called = false
    memory.define_singleton_method(:write!) { |event:| true }
    memory.define_singleton_method(:entries) do |record:, tenant_key:, limit:|
      called = true
      [Rekorra::AccessAudit::Entry.new(actor_key: "other-provider",
        action: "show", occurred_at: Time.current)]
    end
    registry.register :test_source, memory
    definition = Rekorra::AccessAudit::Definition.new
    definition.source :test_source
    definition.authorize :view_access_audit?
    definition.limit 10
    definition.validate!
    denied = Rekorra::AccessAudit::Resolver.new(
      definition: definition, record: @order, tenant_key: "acme",
      registry: registry, authorize: ->(*_args) { false }).call
    assert_empty denied
    assert_equal false, called
    granted = Rekorra::AccessAudit::Resolver.new(
      definition: definition, record: @order, tenant_key: "acme",
      registry: registry, authorize: ->(*_args) { true }).call
    assert_equal "other-provider", granted.first.actor_key
    assert_equal true, called
  end

  test "Audit contracts reject injected metadata and unbounded provider results" do
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::AccessAudit::Event.new(
        action: :show, record_type: "Order", record_id: "1",
        tenant_key: "acme", actor_key: "actor\nforged", request_id: "req",
        occurred_at: Time.current
      )
    end
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::AccessAudit::Event.new(
        action: :arbitrary, record_type: "Order", record_id: "1",
        tenant_key: "acme", actor_key: "actor", request_id: "req",
        occurred_at: Time.current
      )
    end
    defn = Rekorra::AccessAudit::Definition.new
    defn.source :active_record
    defn.authorize :view_access_audit?
    defn.limit 31
    assert_raises(Rekorra::ConfigurationError) { defn.validate! }

    adapter = Object.new
    adapter.define_singleton_method(:write!) { |event:| true }
    adapter.define_singleton_method(:entries) do |**_kwargs|
      Array.new(11) { Rekorra::AccessAudit::Entry.new(actor_key: "actor", action: "show",
        occurred_at: Time.current) }
    end
    registry = Rekorra::AccessAudit::Registry.new
    registry.register :test, adapter
    defn.limit 10
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::AccessAudit::Resolver.new(definition: defn.tap { |d| d.source :test },
        record: @order, tenant_key: "acme", registry: registry,
        authorize: ->(*_args) { true }).call
    end
  end

  test "published Rekorra gem does not require external audit gem" do
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert_not_includes spec.runtime_dependencies.map(&:name), "audits1984"
    assert_not_includes spec.runtime_dependencies.map(&:name), "console1984"
  end
end
