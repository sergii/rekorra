# frozen_string_literal: true

# Demo-only HTTP Basic adapter. Never ship a production app with this policy.
Rekorra.configure do |config|
  config.authenticate_with = lambda do |controller|
    ActionController::HttpAuthentication::Basic.authenticate(controller) do |username, password|
      secret = ENV["REKORRA_DEMO_PASSWORD"]
      next nil if secret.nil? || secret.empty?
      next nil unless ActiveSupport::SecurityUtils.secure_compare(password, secret)

      username == "demo" ? username : nil
    end
  end

  config.authorize_with = ->(actor, _subject, action) { actor == "demo" && action == :access? }
  config.scope_with = ->(_actor, model) { model.none }
end
