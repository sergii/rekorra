# frozen_string_literal: true

require_relative "test_helper"

class TypedFormControlsTest < ActionDispatch::IntegrationTest
  setup do
    @previous = ENV["REKORRA_DEMO_PASSWORD"]
    ENV["REKORRA_DEMO_PASSWORD"] = "test-password"
    @acme = Organization.create!(name: "Acme", slug: "acme")
    @globex = Organization.create!(name: "Globex", slug: "globex")
    @case = CaseRecord.create!(organization: @acme, title: "Before", state: "open",
      flagged: true, due_on: Date.new(2026, 10, 24), estimated_hours: 12.5,
      reviewed_at: Time.utc(2026, 10, 24, 13, 45), notes: "Existing note")
  end

  teardown { ENV["REKORRA_DEMO_PASSWORD"] = @previous }

  def auth(slug = "acme")
    { "HTTP_AUTHORIZATION" =>
      ActionController::HttpAuthentication::Basic.encode_credentials(slug, "test-password") }
  end

  def token_for(page, action)
    get page, headers: auth
    assert_response :success
    node = Nokogiri::HTML(response.body).at_css(
      "form[action='#{action}'] input[name='authenticity_token']"
    )
    assert node
    node["value"]
  end

  test "form renders native controls from actual Rails attribute types" do
    get "/backoffice/resources/cases/#{@case.id}/edit", headers: auth
    assert_response :success
    assert_select "input[type='checkbox'][name='record[flagged]']"
    assert_select "input[type='hidden'][name='record[flagged]'][value='0']"
    assert_select "input[type='date'][name='record[due_on]']"
    assert_select "input[type='number'][name='record[estimated_hours]'][step='any']"
    assert_select "input[type='datetime-local'][name='record[reviewed_at]']"
    assert_select "textarea[name='record[notes]']", text: "Existing note"
    assert_select "input[type='text'][name='record[title]']"
    assert_select "select[name='record[state]']"
    assert_select "select[name='record[organization_id]']"
  end

  test "typed CREATE submits valid values without JavaScript and persists them" do
    url = "/backoffice/resources/cases"
    token = token_for("#{url}/new", url)
    new_id = nil
    assert_difference("CaseRecord.count", 1) do
      post url, headers: auth, params: {
        authenticity_token: token,
        record: {
          title: "Native types", organization_id: @acme.id.to_s, state: "reviewing",
          flagged: "1", due_on: "2026-12-31", estimated_hours: "7.25",
          reviewed_at: "2026-10-28T09:45", notes: "Typed create"
        }
      }
      new_id = CaseRecord.order(:id).last.id
    end
    assert_response :redirect
    created = CaseRecord.find(new_id)
    assert_equal "reviewing", created.state
    assert_equal true, created.flagged
    assert_equal Date.new(2026, 12, 31), created.due_on
    assert_equal "7.25", created.estimated_hours.to_s("F")
    assert_equal "Typed create", created.notes
    assert created.reviewed_at
  end

  test "unchecked checkbox PATCH assigns false, not a missing attribute" do
    url = "/backoffice/resources/cases/#{@case.id}"
    token = token_for("#{url}/edit", url)
    patch url, headers: auth, params: { authenticity_token: token,
      record: { flagged: "0", due_on: "", estimated_hours: "", reviewed_at: "" } }
    assert_response :redirect
    @case.reload
    assert_equal false, @case.flagged
    assert_nil @case.due_on
    assert_nil @case.estimated_hours
    assert_nil @case.reviewed_at
  end

  test "malformed structured fields are denied before partial mutation" do
    url = "/backoffice/resources/cases/#{@case.id}"
    token = token_for("#{url}/edit", url)
    [
      { flagged: "yes" }, { flagged: ["1"] },
      { due_on: "2026-02-30" }, { due_on: "2026-10-28 OR 1=1" },
      { estimated_hours: "NaN" }, { estimated_hours: "1e400" },
      { reviewed_at: "2026-13-28T12:00" },
      { reviewed_at: "2026-10-28T25:00" }
    ].each do |invalid|
      patch url, headers: auth, params: {
        authenticity_token: token, record: { title: "MUTATED" }.merge(invalid)
      }
      assert_response :forbidden, "Input #{invalid.inspect} must fail closed"
      assert_equal "Before", @case.reload.title
      assert_equal true, @case.flagged
    end
  end

  test "forged malformed CREATE cannot persist a partial record" do
    url = "/backoffice/resources/cases"
    token = token_for("#{url}/new", url)
    assert_no_difference("CaseRecord.count") do
      post url, headers: auth, params: {
        authenticity_token: token, record: {
          title: "Invalid", state: "open", organization_id: @acme.id,
          estimated_hours: "something evil" }
      }
    end
    assert_response :forbidden
  end

  test "foreign organization is still rejected as a belongs_to" do
    url = "/backoffice/resources/cases/#{@case.id}"
    token = token_for("#{url}/edit", url)
    patch url, headers: auth, params: { authenticity_token: token,
      record: { organization_id: @globex.id, due_on: "2026-10-29" } }
    assert_response :forbidden
    assert_equal @acme.id, @case.reload.organization_id
  end

  test "integer inputs on existing Orders remain native number controls" do
    customer = Customer.create!(organization: @acme,
      name: "Typed Customer", email: "typed@example.test")
    order = Order.create!(customer: customer, number: "TYPED-ORDER",
      status: "pending", total_cents: 5500)
    get "/backoffice/resources/orders/#{order.id}/edit", headers: auth
    assert_response :success
    assert_select "input[type='number'][name='record[total_cents]'][step='1']"
    assert_select "select[name='record[customer_id]']"
  end

  test "control derives type without needing an explicit as option" do
    cases = {
      flagged: :boolean,
      due_on: :date,
      estimated_hours: :decimal,
      reviewed_at: :datetime,
      notes: :text,
      title: :string,
      state: :enum
    }
    cases.each do |name, expected|
      field = CaseRecordResource.form.fields.find { |f| f.name == name }
      control = Rekorra::Forms::Control.new(model: CaseRecord, field: field)
      assert_equal expected, control.kind
    end
  end
end
