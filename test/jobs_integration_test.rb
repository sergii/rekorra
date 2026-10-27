# frozen_string_literal: true

require_relative "test_helper"

class JobsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @previous = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @order = Order.create!(customer: @alice, number: "ACME-JOB", status: "pending", total_cents: 900)
    @foreign = Order.create!(customer: @bob, number: "GLOBEX-JOB", status: "pending", total_cents: 400)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous }

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def enqueue_linked(order)
    enqueued = OrderReceiptJob.perform_later(order.id)
    assert enqueued
    assert enqueued.successfully_enqueued?
    DemoJobLink.create!(order: order, active_job_id: enqueued.job_id,
      job_class_name: enqueued.class.name)
    enqueued
  end

  test "real Solid Queue job is visible only through explicit Order link" do
    job = enqueue_linked(@order)
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    section = Nokogiri::HTML(response.body).at_css("section.rk-jobs")
    assert section
    assert_includes section.text, "OrderReceiptJob"
    assert_includes section.text, job.job_id
    assert_includes section.text, "Queued"
    assert_not_includes section.text, "serialized_arguments"
    assert_not_includes section.text, "password"
    assert_select "section.rk-jobs li.rk-jobs__item", count: 1
  end

  test "other tenant's job IDs do not leak on same resource" do
    own = enqueue_linked(@order)
    other = enqueue_linked(@foreign)

    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_includes response.body, own.job_id
    assert_not_includes response.body, other.job_id

    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers
    assert_response :not_found
  end

  test "view_jobs has independent policy" do
    foreign_job = enqueue_linked(@foreign)
    get "/backoffice/resources/orders/#{@foreign.id}", headers: headers("globex")
    assert_response :success
    assert_select "section.rk-jobs", count: 0
    assert_not_includes response.body, foreign_job.job_id
  end

  test "unauthenticated request cannot see jobs" do
    enqueue_linked(@order)
    get "/backoffice/resources/orders/#{@order.id}"
    assert_response :unauthorized
    assert_select "section.rk-jobs", count: 0
  end

  test "completed job is reflected in Order and backend state" do
    job = enqueue_linked(@order)
    # Work is explicit; it does not happen merely because the job is enqueued.
    assert_nil @order.reload.receipt_generated_at
    OrderReceiptJob.perform_now(@order.id)
    assert @order.reload.receipt_generated_at

    backend = ::SolidQueue::Job.find_by!(active_job_id: job.job_id)
    backend.update!(finished_at: Time.current)
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-jobs .rk-badge", text: "Finished"
  end

  test "failed backend record shows failed without showing error payload" do
    job = enqueue_linked(@order)
    backend = ::SolidQueue::Job.find_by!(active_job_id: job.job_id)
    ::SolidQueue::FailedExecution.create!(job_id: backend.id,
      error: { exception_class: "RuntimeError", message: "secret-token-123",
        backtrace: ["private/path:42"] })
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-jobs .rk-badge", text: "Failed"
    assert_not_includes response.body, "secret-token-123"
    assert_not_includes response.body, "private/path:42"
  end

  test "stale correlation is reported as unavailable, not guessed" do
    DemoJobLink.create!(order: @order,
      active_job_id: "not-present-in-queue", job_class_name: "OrderReceiptJob")
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-jobs .rk-badge", text: "Unavailable"
  end

  test "job display is bounded to the newest ten links" do
    13.times do |n|
      DemoJobLink.create!(order: @order, active_job_id: "missing-#{n}",
        job_class_name: "OrderReceiptJob")
    end
    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_select "section.rk-jobs li.rk-jobs__item", count: 10
    assert_not_includes Nokogiri::HTML(response.body).at_css("section.rk-jobs").text, "missing-0"
  end

  test "OrderReceiptJob is idempotent across repeated performs" do
    OrderReceiptJob.perform_now(@order.id)
    first = @order.reload.receipt_generated_at
    assert first
    OrderReceiptJob.perform_now(@order.id)
    assert_equal first, @order.reload.receipt_generated_at
  end

  test "source can be replaced with a fake read-only jobs adapter" do
    adapter = Object.new
    invoked = false
    adapter.define_singleton_method(:jobs) do |record:, limit:|
      invoked = true
      [Rekorra::Jobs::Item.new(
        id: "domain-1", name: "ExternalWorker", queue: "critical", status: "finished",
        created_at: Time.utc(2026, 10, 28)
      )]
    end
    registry = Rekorra::Jobs::Registry.new
    registry.register :external_jobs, adapter
    resource = Class.new do
      define_singleton_method(:jobs) do
        Rekorra::Jobs::Definition.new.tap do |definition|
          definition.source :external_jobs
          definition.authorize :view_jobs?
        end
      end
    end
    result = Rekorra::Jobs::Resolver.new(resource: resource, record: @order,
      authorize: ->(_record, policy) { policy == :view_jobs? }, registry: registry).call
    assert invoked
    assert_equal "ExternalWorker", result.first.name
    assert_equal "finished", result.first.status
  end

  test "denied access never fetches job status" do
    invoked = false
    adapter = Object.new
    adapter.define_singleton_method(:jobs) { |**_args| invoked = true; [] }
    registry = Rekorra::Jobs::Registry.new
    registry.register :solid_queue, adapter
    result = Rekorra::Jobs::Resolver.new(resource: OrderResource, record: @order,
      authorize: ->(_record, _policy) { false }, registry: registry).call
    assert_empty result
    assert_equal false, invoked
  end

  test "job contract enforces bounded results" do
    adapter = Object.new
    adapter.define_singleton_method(:jobs) do |**_args|
      Array.new(11) { Rekorra::Jobs::Item.new(id: "x") }
    end
    registry = Rekorra::Jobs::Registry.new
    registry.register :solid_queue, adapter
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::Jobs::Resolver.new(resource: OrderResource, record: @order,
        authorize: ->(_record, _policy) { true }, registry: registry).call
    end
  end

  test "host dependency is optional for published Rekorra gem" do
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert spec
    assert_not_includes spec.runtime_dependencies.map(&:name), "solid_queue"
  end
end
