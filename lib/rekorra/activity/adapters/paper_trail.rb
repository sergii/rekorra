# frozen_string_literal: true

module Rekorra
  module Activity
    module Adapters
      # No required PaperTrail gem dependency. The host installs and configures it.
      # Only fields explicitly declared by the resource can reach the UI.
      class PaperTrail
        MAX_VALUE_BYTES = 200

        def events(record:, fields:, limit:)
          unless record.respond_to?(:versions) && defined?(::PaperTrail)
            raise ConfigurationError, "PaperTrail is not installed on #{record.class}"
          end

          record.versions.order(created_at: :desc, id: :desc).limit(limit).map do |version|
            changeset = version.changeset
            changes = if changeset.is_a?(Hash)
              fields.filter_map do |field|
                values = changeset[field] || changeset[field.to_sym]
                next unless values.is_a?(Array) && values.size == 2

                Change.new(field: field.to_s,
                  before: present_value(values.first),
                  after: present_value(values.last))
              end
            else
              []
            end

            Event.new(
              kind: version.event.to_s,
              at: version.created_at,
              actor: present_value(version.whodunnit || "Unknown"),
              changes: changes
            )
          end
        end

        def with_actor(actor:)
          raise ConfigurationError, "PaperTrail is not installed" unless defined?(::PaperTrail)
          identifier = actor.to_s
          raise ConfigurationError, "Activity actor must be present" if identifier.strip.empty?

          ::PaperTrail.request(whodunnit: identifier) { yield }
        end

        private

        def present_value(value)
          return "(none)" if value.nil?
          # Keep the UI bounded; avoid rendering nested arbitrary objects.
          text = value.is_a?(String) || value.is_a?(Numeric) ||
            value == true || value == false ? value.to_s : "(structured value)"
          text.byteslice(0, MAX_VALUE_BYTES).to_s.scrub
        end
      end
    end
  end
end
