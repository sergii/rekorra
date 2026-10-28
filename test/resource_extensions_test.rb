# frozen_string_literal: true

require_relative "test_helper"
require "pundit"

# Real Pundit policy used by the optional adapter integration test.
class OrderPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user, @record = user, record
  end

  def index?
    user.is_a?(Organization)
  end

  def show?
    record.is_a?(Order) && record.customer.organization_id == user.id
  end

  def update?
    show? && user.slug == "acme"
  end

  def view_total_cents?
    show? && user.slug == "acme"
  end

  class Scope
    def initialize(user, scope)
      @user, @scope = user, scope
    end

    def resolve
      @scope.joins(:customer).where(customers: { organization_id: @user.id })
    end
  end
end

class ResourceExtensionsTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @alice = Customer.create!(organization: @acme, name: "Alice", email: "alice@example.test")
    @bob = Customer.create!(organization: @globex, name: "Bob", email: "bob@example.test")
    @order = Order.create!(customer: @alice, number: "EXT-ACME", status: "pending", total_cents: 1000)
    @case = CaseRecord.create!(organization: @acme, title: "Demo Case", state: "open")
    @foreign = Order.create!(customer: @bob, number: "EXT-GLOBEX", status: "pending", total_cents: 2000)
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous_password }

  def headers(tenant = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(tenant, "test-password") }
  end

  test "Rails enum renders allowlisted choices and persists valid values" do
    get "/backoffice/resources/cases/#{@case.id}/edit", headers: headers
    assert_response :success
    options = Nokogiri::HTML(response.body).css("select[name='record[state]'] option")
    assert_equal %w[open reviewing closed], options.map { |option| option["value"] }.reject(&:empty?)
    assert_equal "open", options.find { |option| option["selected"] }["value"]

    csrf = Nokogiri::HTML(response.body).at_css("form.rk-form input[name='authenticity_token']")["value"]
    patch "/backoffice/resources/cases/#{@case.id}", headers: headers,
      params: { authenticity_token: csrf, record: { state: "reviewing" } }
    assert_response :redirect
    assert_equal "reviewing", @case.reload.state
  end

  test "forged enum value is rejected before model assignment or persistence" do
    get "/backoffice/resources/cases/#{@case.id}/edit", headers: headers
    csrf = Nokogiri::HTML(response.body).at_css("form.rk-form input[name='authenticity_token']")["value"]
    patch "/backoffice/resources/cases/#{@case.id}", headers: headers,
      params: { authenticity_token: csrf, record: { state: "superadmin" } }
    assert_response :forbidden
    assert_equal "open", @case.reload.state

    get "/backoffice/resources/cases/new", headers: headers
    csrf = Nokogiri::HTML(response.body).at_css("form.rk-form input[name='authenticity_token']")["value"]
    assert_no_difference "CaseRecord.count" do
      post "/backoffice/resources/cases", headers: headers, params: {
        authenticity_token: csrf, record: { title: "FORGED-ENUM", organization_id: @acme.id,
          state: "superadmin" }
      }
    end
    assert_response :forbidden
  end

  test "invalid enum DSL declaration fails closed" do
    klass = Class.new(Rekorra::Resource) do
      model "CaseRecord"
      form { field :title, as: :enum }
    end
    assert_raises(Rekorra::ConfigurationError) { klass.validate! }
    spec = Gem::Specification.load(File.expand_path("../rekorra.gemspec", __dir__))
    assert_not_includes spec.runtime_dependencies.map(&:name), "pundit"
  end

  test "real Pundit policy authorizes model and scoped record independently" do
    adapter = Rekorra::Authorization::Adapters::Pundit.new
    assert_equal true, adapter.call(@acme, Order, :index?)
    assert_equal true, adapter.call(@acme, @order, :show?)
    assert_equal false, adapter.call(@acme, @foreign, :show?)
    assert_equal false, adapter.call(@globex, @foreign, :update?)
    assert_equal true, adapter.call(@acme, @order, :view_total_cents?)
    assert_equal false, adapter.call(@globex, @foreign, :view_total_cents?)
    assert_equal false, adapter.call(@acme, @order, :undeclared_action?)
  end

  test "Pundit scope returns only the tenant relation and no unscoped fallback" do
    adapter = Rekorra::Authorization::Adapters::PunditScope.new
    own = adapter.call(@acme, Order)
    assert_kind_of ActiveRecord::Relation, own
    assert_equal Order, own.klass
    assert_equal [@order.id], own.pluck(:id)
    assert_equal [@foreign.id], adapter.call(@globex, Order).pluck(:id)
    assert_raises(Rekorra::ConfigurationError) { adapter.call(@acme, User) }
  end

  test "Pundit adapters are accepted through the ordinary security configuration contract" do
    config = Rekorra::Configuration.new
    config.authenticate_with = ->(_controller) { @acme }
    config.authorize_with = Rekorra::Authorization::Adapters::Pundit.new
    config.scope_with = Rekorra::Authorization::Adapters::PunditScope.new
    assert_nil config.ready!
    assert config.authorize_with.call(@acme, @order, :show?)
    assert_equal [@order.id], config.scope_with.call(@acme, Order).pluck(:id)
  end

  test "association lookup ships optional enhancement but keeps HTML GET fallback" do
    get "/backoffice/resources/orders/new", headers: headers
    assert_response :success
    assert_select "form[data-rk-association-lookup='true'][method='get']"
    assert_select "form[data-rk-association-lookup] [role='status'][aria-live='polite']"
    assert_select "script[src*='/assets/rekorra/associations-']"
    assert_select "select[name='record[customer_id]']"
  end
end
