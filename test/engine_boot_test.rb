# frozen_string_literal: true

require_relative "test_helper"

class EngineBootTest < ActionDispatch::IntegrationTest
  test "unauthenticated users receive unauthorized" do
    get "/backoffice"
    assert_response :unauthorized
  end

  test "authenticated users can view engine shell and resources" do
    organization = Organization.create!(slug: "acme", name: "Acme")
    previous = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    get "/backoffice", headers: {
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(organization.slug, "test-password")
    }
    assert_response :success
    assert_includes response.body, "Rekorra engine is mounted"
    assert_includes response.body, "Orders"
  ensure
    ENV["REKORRA_DEMO_PASSWORD"] = previous
  end
end
