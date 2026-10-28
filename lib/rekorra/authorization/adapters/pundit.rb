# frozen_string_literal: true

module Rekorra
  module Authorization
    module Adapters
      # Optional bridge to policies defined by the host application.
      # Call via config.authorize_with. Rekorra does not depend on Pundit.
      class Pundit
        def call(actor, subject, action)
          ensure_installed!
          return false unless action.is_a?(Symbol) && action.to_s.end_with?("?")
          policy = ::Pundit.policy(actor, subject)
          policy && policy.respond_to?(action) && policy.public_send(action) == true
        end

        private

        def ensure_installed!
          unless defined?(::Pundit) && ::Pundit.respond_to?(:policy)
            raise ConfigurationError, "Pundit is not installed in host application"
          end
        end
      end

      # Separate SQL-level scope: must never return a plain Array or Model.all
      # fallback when no policy scope exists.
      class PunditScope
        def call(actor, model)
          unless defined?(::Pundit) && ::Pundit.respond_to?(:policy_scope)
            raise ConfigurationError, "Pundit is not installed in host application"
          end
          result = ::Pundit.policy_scope(actor, model)
          unless result.is_a?(ActiveRecord::Relation) && result.klass == model
            raise ConfigurationError, "Missing or invalid Pundit SQL scope for #{model}"
          end
          result
        end
      end
    end
  end
end
