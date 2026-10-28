require "sidekiq/api"
# frozen_string_literal: true

# Demo-only Basic authentication. A real host must use its own auth and policies.
Rekorra.configure do |config|
  config.index_cursor_context_with = ->(actor) { "organization:#{actor.id}" }
  config.finding_rules.register :paid_but_pending, "PaidButPending"

  config.job_adapters.register :solid_queue,
    Rekorra::Jobs::Adapters::SolidQueue.new(links: ->(order) { order.demo_job_links.where(provider: "solid_queue") })
  config.job_adapters.register :sidekiq,
    Rekorra::Jobs::Adapters::Sidekiq.new(
      links: ->(order) { order.demo_job_links.where(provider: "sidekiq") }
    )

  config.activity_actor_with = ->(actor) { "demo-organization:#{actor.slug}" }
  config.activity_adapters.register :paper_trail, Rekorra::Activity::Adapters::PaperTrail.new
  config.context_application = "rekorra-demo"
  config.context_environment = Rails.env
  config.context_tenant_with = ->(actor) { actor.slug }
  config.authenticate_with = lambda do |controller|
    actor = ActionController::HttpAuthentication::Basic.authenticate(controller.request) do |username, password|
      secret = ENV["REKORRA_DEMO_PASSWORD"]
      next nil if secret.nil? || secret.empty?
      next nil unless ActiveSupport::SecurityUtils.secure_compare(password, secret)

      Organization.find_by(slug: username)
    end
    controller.response.set_header("WWW-Authenticate", 'Basic realm="Rekorra Demo"') unless actor
    actor
  end

  # Authorization decides whether an action is allowed.
  # Scope adapters enforce organization-level row visibility.
  config.external_link_allowed_hosts = %w[github.com service.sumologic.com]
  config.external_services[:sumo_logic] = { base_url: "https://service.sumologic.com" }

  config.authorize_with = lambda do |actor, subject, action|
    next false unless actor.is_a?(Organization)
    next true if subject.nil? && action == :access?

    model_name = subject.is_a?(Class) ? subject.name : subject.class.name
    next false unless %w[Organization Customer Order Payment User].include?(model_name)
    if model_name == "User"
      next %i[index? show?].include?(action)
    end
    if model_name == "Organization"
      next %i[index? show?].include?(action) &&
        (subject.is_a?(Class) || subject.id == actor.id)
    end
    next actor.slug == "acme" if action == :view_total_cents?
    next actor.slug == "acme" if action == :edit_total_cents?
    next actor.slug == "acme" if action == :view_findings?
    next actor.slug == "acme" if action == :view_jobs?
    next actor.slug == "acme" if action == :view_activity?
    next actor.slug == "acme" if action == :view_logs?
    next true if action == :view_issues?

    allowed = %i[index? show? create? edit? update? destroy?]
    next false unless allowed.include?(action)
    !(%w[Customer].include?(model_name) && !%i[index? show?].include?(action))
  end

  config.scope_with = lambda do |actor, model|
    next model.none unless actor.is_a?(Organization)

    case model.name
    when "Organization" then model.where(id: actor.id)
    when "User" then model.where(organization_id: actor.id)
    when "Customer" then model.where(organization_id: actor.id)
    when "Order" then model.joins(:customer).where(customers: { organization_id: actor.id })
    when "Payment" then model.joins(order: :customer).where(customers: { organization_id: actor.id })
    else model.none
    end
  end

  config.resource :organizations, "OrganizationResource"
  config.resource :users, "UserResource"
  config.resource :cursor_users, "CursorUserResource"
  config.resource :customers, "CustomerResource"
  config.resource :orders, "OrderResource"
  config.resource :sidekiq_orders, "SidekiqOrderResource"
  config.resource :payments, "PaymentResource"
end
