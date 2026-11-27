# frozen_string_literal: true

require_relative "test_helper"

class CrmDogfoodNavigationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_password = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @headers = { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("acme", "test-password") }
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous_password }

  test "CRM groups and registered resources appear in the engine sidebar" do
    get "/backoffice", headers: @headers
    assert_response :success
    assert_select "nav[aria-label='Backoffice resources']" do
      assert_select "summary", text: "CRM"
      assert_select "summary", text: "Sales"
      assert_select "a", text: "Leads"
      assert_select "a", text: "Customer onboarding"
    end
  end

  test "onboarding filters by stage and health without leaking tenant data" do
    own = create_onboarding(@acme, "Own unknown", "unknown")
    foreign = create_onboarding(@globex, "Foreign unknown", "unknown")
    create_onboarding(@acme, "Own healthy", "healthy")
    get "/backoffice/resources/crm_onboardings", headers: @headers,
      params: { filters: { stage: "dispatched", health: "unknown" } }
    assert_response :success
    assert_select "table.rk-table tbody tr", count: 1
    assert_includes response.body, own.company_name
    assert_not_includes response.body, foreign.company_name
    assert_not_includes response.body, "Own healthy"
    get "/backoffice/resources/crm_onboardings/#{foreign.id}", headers: @headers
    assert_response :not_found
    get "/backoffice/resources/crm_onboardings/#{own.id}/edit", headers: @headers
    assert_response :forbidden
  end

  test "navigation excludes unauthorized resources before constructing groups" do
    tree = Rekorra::Navigation.build(resources: { "crm_leads" => "Crm::LeadResource", "crm_onboardings" => "Crm::OnboardingResource" },
      strategy: :namespace, resolve: Rekorra.method(:resource_for),
      allowed: ->(model, _action) { model == Crm::Lead })
    crm = tree[:groups].fetch("CRM")
    assert_equal ["Sales"], crm[:groups].keys
    assert_equal "crm_leads", crm[:groups]["Sales"][:items].first[:slug]
  end

  test "alphabetical navigation ignores group overrides" do
    tree = Rekorra::Navigation.build(resources: { "crm_leads" => "Crm::LeadResource", "crm_onboardings" => "Crm::OnboardingResource" },
      strategy: :alphabetical, resolve: Rekorra.method(:resource_for), allowed: ->(*) { true })
    assert_empty tree[:groups]
    assert_equal %w[crm_onboardings crm_leads], tree[:items].map { |item| item[:slug] }
  end

  private

  def create_onboarding(organization, name, health)
    Crm::Onboarding.create!(organization: organization, reference: name,
      company_name: name, stage: "dispatched", health: health,
      assigned_to: "Jamie", stage_entered_at: Time.current)
  end
end
