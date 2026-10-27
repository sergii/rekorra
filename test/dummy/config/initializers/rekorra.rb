# frozen_string_literal: true

# Demo-only Basic authentication. A real host must use its own auth and policies.
Rekorra.configure do |config|
  config.authenticate_with = lambda do |controller|
    ActionController::HttpAuthentication::Basic.authenticate(controller.request) do |username, password|
      secret = ENV["REKORRA_DEMO_PASSWORD"]
      next nil if secret.nil? || secret.empty?
      next nil unless ActiveSupport::SecurityUtils.secure_compare(password, secret)

      Organization.find_by(slug: username)
    end
  end

  # Authorization decides whether an action is allowed.
  # Scope adapters enforce organization-level row visibility.
  config.authorize_with = lambda do |actor, subject, action|
    next false unless actor.is_a?(Organization)
    next true if subject.nil? && action == :access?

    model_name = subject.is_a?(Class) ? subject.name : subject.class.name
    next false unless %w[Customer Order Payment].include?(model_name)
    allowed = %i[index? show? create? edit? update? destroy?]
    next false unless allowed.include?(action)
    !(%w[Customer].include?(model_name) && !%i[index? show?].include?(action))
  end

  config.scope_with = lambda do |actor, model|
    next model.none unless actor.is_a?(Organization)

    case model.name
    when "Customer" then model.where(organization_id: actor.id)
    when "Order" then model.joins(:customer).where(customers: { organization_id: actor.id })
    when "Payment" then model.joins(order: :customer).where(customers: { organization_id: actor.id })
    else model.none
    end
  end

  config.resource :customers, "CustomerResource"
  config.resource :orders, "OrderResource"
  config.resource :payments, "PaymentResource"
end
