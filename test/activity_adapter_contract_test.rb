# frozen_string_literal: true

require_relative "test_helper"

class ActivityAdapterContractTest < ActiveSupport::TestCase
  class ReadOnlyEventSource
    attr_reader :last_call

    def events(record:, fields:, limit:)
      @last_call = { record: record, fields: fields, limit: limit }
      [
        Rekorra::Activity::Event.new(
          kind: "workflow_transition",
          at: Time.utc(2026, 10, 28, 12),
          actor: "external-processor",
          changes: [Rekorra::Activity::Change.new(
            field: "status", before: "pending", after: "paid"
          )]
        )
      ]
    end
  end

  def custom_resource
    Class.new(Rekorra::Resource) do
      model "Order"
      activity do
        source :domain_events
        fields :status
        authorize :view_activity?
        limit 7
      end
    end
  end

  test "a non PaperTrail adapter can be registered and resolved without changing Core" do
    registry = Rekorra::Activity::Registry.new
    source = ReadOnlyEventSource.new
    registry.register(:domain_events, source)

    resource = custom_resource
    resource.validate!
    record = Order.new(number: "A-101", status: "paid", total_cents: 100)

    events = Rekorra::Activity::Resolver.new(
      resource: resource, record: record, registry: registry,
      authorize: ->(_record, policy) { policy == :view_activity? }
    ).call

    assert_equal({ record: record, fields: ["status"], limit: 7 }, source.last_call)
    assert_equal 1, events.size
    assert_equal "workflow_transition", events.first.kind
    assert_equal "external-processor", events.first.actor
    assert_equal ["status", "pending", "paid"],
      [events.first.changes.first.field,
       events.first.changes.first.before,
       events.first.changes.first.after]
  end

  test "a read only activity source does not require a write actor hook" do
    resource = custom_resource
    source = ReadOnlyEventSource.new
    # The controller resolves writers from the host-configured registry.
    Rekorra.configuration.activity_adapters.register(:domain_events, source)

    controller = Rekorra::ResourcesController.new
    controller.instance_variable_set(:@resource, resource)
    assert_equal "saved", controller.send(:with_activity_actor) { "saved" }
  end

  test "adapter registry rejects sources without event reading" do
    registry = Rekorra::Activity::Registry.new
    assert_raises(Rekorra::ConfigurationError) do
      registry.register(:invalid, Object.new)
    end
  end
end
