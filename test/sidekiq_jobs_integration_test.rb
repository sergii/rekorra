# frozen_string_literal: true

require_relative "test_helper"
require "sidekiq/api"

class SidekiqJobsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    ::Sidekiq.redis { |connection| connection.flushdb }

    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "Bob@example.test")
    @order = Order.create!(customer: @alice, number: "ACME-SIDEKIQ", status: "pending", total_cents: 100)
    @foreign = Order.create!(customer: @bob, number: "GLOBEX-SIDEKIQ", status: "pending", total_cents: 100)
  end

  teardown do
    ENV["REKORRA_DEMO_PASSWORD"] = @previous_password
    ::Sidekiq.redis { |connection| connection.flushdb }
  end

  def headers(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def link(order, jid, queue: "default")
    DemoJobLink.create!(order: order, provider: "sidekiq", queue_name: queue,
      active_job_id: jid, job_class_name: "SidekiqOrderReceiptWorker")
  end

  def show_order(order = @order, slug: "acme")
    get "/backoffice/resources/sidekiq_orders/#{order.id}", headers: headers(slug)
  end

  def push_payload(jid:, set:)
    payload = {
      "class" => "SidekiqOrderReceiptWorker", "args" => [@order.id],
      "queue" => "default", "jid" => jid, "retry" => true,
      "created_at" => Time.current.to_f, "enqueued_at" => Time.current.to_f,
      "error_message" => "SENSITIVE-SECRET-should-not-be-shown"
    }
    ::Sidekiq.redis do |c|
      c.zadd(set, Time.current.to_f + 3600, ::Sidekiq.dump_json(payload))
    end
  end

  test "real Sidekiq enqueued job appears in provider-specific Order page" do
    jid = SidekiqOrderReceiptWorker.perform_async(@order.id)
    assert jid
    link(@order, jid)

    show_order
    assert_response :success
    assert_select "section.rk-jobs li.rk-jobs__item", count: 1
    assert_includes response.body, jid
    assert_select "section.rk-jobs .rk-badge", text: "Queued"
    assert_not_includes response.body, "SENSITIVE-SECRET"
    assert_not_includes response.body, "args"
  end

  test "Sidekiq and SolidQueue job links remain provider-separated" do
    sidekiq_jid = SidekiqOrderReceiptWorker.perform_async(@order.id)
    link(@order, sidekiq_jid)
    regular_id = "fake-solid-#{@order.id}"
    DemoJobLink.create!(order: @order, active_job_id: regular_id,
      job_class_name: "OrderReceiptJob")

    show_order
    assert_response :success
    assert_includes response.body, sidekiq_jid
    assert_not_includes response.body, regular_id

    get "/backoffice/resources/orders/#{@order.id}", headers: headers
    assert_response :success
    assert_includes response.body, regular_id
    assert_not_includes response.body, sidekiq_jid
  end

  test "cross-tenant JIDs are never displayed" do
    jid = SidekiqOrderReceiptWorker.perform_async(@foreign.id)
    link(@foreign, jid)
    show_order
    assert_response :success
    assert_not_includes response.body, jid

    show_order(@foreign)
    assert_response :not_found
  end

  test "view_jobs is a distinct policy" do
    jid = SidekiqOrderReceiptWorker.perform_async(@foreign.id)
    link(@foreign, jid)
    show_order(@foreign, slug: "globex")
    assert_response :success
    assert_select "section.rk-jobs", count: 0
    assert_not_includes response.body, jid
  end

  test "anonymous access cannot inspect Redis or job statuses" do
    jid = SidekiqOrderReceiptWorker.perform_async(@order.id)
    link(@order, jid)
    get "/backoffice/resources/sidekiq_orders/#{@order.id}"
    assert_response :unauthorized
    assert_not_includes response.body, jid
  end

  test "scheduled, retrying and dead records project without leaking serialized errors" do
    %w[schedule retry dead].each do |set|
      jid = "example-#{set}"
      push_payload(jid: jid, set: set)
      link(@order, jid)
    end

    show_order
    assert_response :success
    assert_select "section.rk-jobs .rk-badge", text: "Scheduled"
    assert_select "section.rk-jobs .rk-badge", text: "Retrying"
    assert_select "section.rk-jobs .rk-badge", text: "Dead"
    assert_not_includes response.body, "SENSITIVE-SECRET-should-not-be-shown"
  end

  test "no JID match is not falsely marked finished" do
    link(@order, "not-in-redis")
    show_order
    assert_response :success
    assert_select "section.rk-jobs .rk-badge", text: "Unavailable"
    assert_select "section.rk-jobs .rk-badge", text: "Finished", count: 0
  end

  test "bounded scanning does not imply false positives for older queued jobs" do
    old = SidekiqOrderReceiptWorker.perform_async(@order.id)
    3.times { SidekiqOrderReceiptWorker.perform_async(@order.id) }
    link(@order, old)
    adapter = Rekorra::Jobs::Adapters::Sidekiq.new(
      links: ->(order) { order.demo_job_links.where(provider: "sidekiq") },
      scan_limit: 1
    )
    items = adapter.jobs(record: @order, limit: 10)
    assert_equal 1, items.size
    assert_includes %w[queued unavailable], items.first.status
    assert_raises(Rekorra::ConfigurationError) do
      Rekorra::Jobs::Adapters::Sidekiq.new(links: ->(order) { order.demo_job_links },
        scan_limit: 1000)
    end
  end

  test "SidekiqOrderReceiptWorker is idempotent on direct perform" do
    worker = SidekiqOrderReceiptWorker.new
    worker.perform(@order.id)
    first = @order.reload.receipt_generated_at
    assert first
    worker.perform(@order.id)
    assert_equal first, @order.reload.receipt_generated_at
  end

  test "Sidekiq remains an optional dependency of Rekorra gem" do
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert spec
    assert_not_includes spec.runtime_dependencies.map(&:name), "sidekiq"
  end
end
