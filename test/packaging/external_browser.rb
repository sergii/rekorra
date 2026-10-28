# frozen_string_literal: true

# Run from a brand-new directory, outside the checkout and outside Bundler.
# All Rails models, routes, importmaps and authorization belong to this host.
require "rubygems"
require "pathname"
require "fileutils"
require "securerandom"
require "net/http"
require "json"
require "rails/all"
require "rack/mock"
require "capybara"
require "capybara/dsl"
require "selenium-webdriver"

stack = ENV.fetch("REKORRA_EXTERNAL_BROWSER_STACK")
abort "Unsupported pipeline" unless %w[propshaft sprockets].include?(stack)
if stack == "propshaft"
  require "propshaft"
  require "propshaft/railtie"
else
  require "sprockets/railtie"
end
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"
require "rekorra"

spec = Gem::Specification.find_by_name("rekorra")
source_root = ENV.fetch("GITHUB_WORKSPACE")
abort "Loaded Rekorra from checkout rather than installed gem" if
  spec.full_gem_path.start_with?("#{source_root}/")
abort "Missing installed Rekorra engine" unless File.file?(
  File.join(spec.full_gem_path, "app/views/rekorra/resources/index.html.erb")
)

def host_file(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
end

host_file("config/database.yml", <<~YAML)
  test:
    adapter: sqlite3
    database: #{File.join(Dir.pwd, "external-browser.sqlite3")}
    pool: 10
YAML
host_file("config/importmap.rb", <<~RUBY)
  pin "application", to: "application.js"
  pin "controllers/probe_controller", to: "controllers/probe_controller.js"
  pin "@hotwired/turbo-rails", to: "turbo.min.js"
  pin "@hotwired/stimulus", to: "stimulus.min.js"
RUBY
host_file("app/javascript/application.js", <<~JS)
  import "@hotwired/turbo-rails"
  import { Application } from "@hotwired/stimulus"
  import ProbeController from "controllers/probe_controller"

  window.Stimulus = Application.start()
  window.Stimulus.register("rekorra-probe", ProbeController)
JS
host_file("app/javascript/controllers/probe_controller.js", <<~JS)
  import { Controller } from "@hotwired/stimulus"
  export default class extends Controller {
    connect() { this.element.dataset.rkProbeConnected = "true" }
  }
JS
if stack == "sprockets"
  host_file("app/assets/config/manifest.js", <<~JS)
    //= link rekorra/application.css
    //= link rekorra/index.js
    //= link rekorra/associations.js
    //= link application.js
    //= link controllers/probe_controller.js
  JS
end

host_file("app/models/external_tenant.rb", <<~RUBY)
  class ExternalTenant < ActiveRecord::Base
    has_many :external_customers
  end
RUBY
host_file("app/models/external_customer.rb", <<~RUBY)
  class ExternalCustomer < ActiveRecord::Base
    belongs_to :external_tenant
    has_many :external_orders
    validates :name, :email, presence: true
  end
RUBY
host_file("app/models/external_order.rb", <<~RUBY)
  class ExternalOrder < ActiveRecord::Base
    belongs_to :external_customer
    validates :number, :status, presence: true
  end
RUBY

host_file("app/resources/external_customer_resource.rb", <<~RUBY)
  class ExternalCustomerResource < Rekorra::Resource
    model "ExternalCustomer"
    index do
      field :name
      field :email
      search_by :name, :email
      sort_by :name, :email
      pagination do
        strategy :offset
        per_page 10
        max_per_page 100
      end
    end
    show do
      field :name
      field :email
    end
  end
RUBY
host_file("app/resources/external_order_resource.rb", <<~RUBY)
  class ExternalOrderResource < Rekorra::Resource
    model "ExternalOrder"
    index do
      field :number
      field :status
      sort_by :number
      pagination do
        strategy :offset
        per_page 10
        max_per_page 100
      end
    end
    show do
      field :number
      field :status
      field :external_customer
    end
    form do
      field :number
      field :status
      field :external_customer_id
    end
  end
RUBY

module ExternalBrowserRekorraHost
  class Application < Rails::Application
    config.root = Pathname.new(Dir.pwd)
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = "external-rekorra-browser-ci-only-" * 3
    config.hosts.clear
    config.session_store :cookie_store, key: "_rekorra_external_browser"
    config.assets.compile = true if ENV.fetch("REKORRA_EXTERNAL_BROWSER_STACK") == "sprockets"
    config.assets.unknown_asset_fallback = false if
      ENV.fetch("REKORRA_EXTERNAL_BROWSER_STACK") == "sprockets"
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.script_src :self
      policy.style_src :self
      policy.connect_src :self
      policy.img_src :self, :data
      policy.object_src :none
    end
    config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[script-src]
  end
end

Rekorra.configure do |config|
  config.authenticate_with = ->(_controller) { ExternalTenant.find_by!(slug: "acme") }
  config.authorize_with = ->(_actor, _subject, action) {
    action == :access? || %i[index? show? create? edit? update?].include?(action)
  }
  config.scope_with = lambda do |actor, model|
    case model.name
    when "ExternalCustomer" then model.where(external_tenant_id: actor.id)
    when "ExternalOrder"
      model.joins(:external_customer).where(
        external_customers: { external_tenant_id: actor.id }
      )
    else model.none
    end
  end
  config.resource :external_customers, "ExternalCustomerResource"
  config.resource :external_orders, "ExternalOrderResource"
end

app = ExternalBrowserRekorraHost::Application
app.initialize!
app.routes.draw { mount Rekorra::Engine => "/backoffice" }

ActiveRecord::Schema.define do
  create_table :external_tenants, force: true do |t|
    t.string :name, null: false
    t.string :slug, null: false
    t.timestamps
  end
  create_table :external_customers, force: true do |t|
    t.references :external_tenant, null: false
    t.string :name, null: false
    t.string :email, null: false
    t.timestamps
  end
  create_table :external_orders, force: true do |t|
    t.references :external_customer, null: false
    t.string :number, null: false
    t.string :status, null: false
    t.timestamps
  end
end

acme = ExternalTenant.create!(name: "Acme", slug: "acme")
globex = ExternalTenant.create!(name: "Globex", slug: "globex")
26.times do |n|
  ExternalCustomer.create!(external_tenant: acme,
    name: "Customer #{n.to_s.rjust(3, "0")}",
    email: "customer-#{n}@external.test")
end
late = ExternalCustomer.create!(external_tenant: acme,
  name: "Exceptional Late Customer", email: "late@external.test")
ExternalCustomer.create!(external_tenant: globex,
  name: "Foreign Tenant Confidential", email: "foreign@external.test")

# Check real CSP response headers, not just application configuration.
request = Rack::MockRequest.new(app)
response = request.get("/backoffice", "HTTP_HOST" => "localhost")
abort "Host failed to mount Rekorra" unless response.status == 200
csp = response.headers["content-security-policy"]
abort "Missing enforced nonce CSP" unless csp &&
  csp.include?("script-src") && csp.include?("nonce-") &&
  !csp.include?("unsafe-inline")

Capybara.register_driver(:external_rekorra_chrome) do |rack_app|
  options = Selenium::WebDriver::Chrome::Options.new
  %w[--headless=new --no-sandbox --disable-dev-shm-usage --disable-gpu].each do |arg|
    options.add_argument(arg)
  end
  Capybara::Selenium::Driver.new(rack_app, browser: :chrome, options: options)
end
Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 12
session = Capybara::Session.new(:external_rekorra_chrome, app)

def verify(condition, message)
  raise message unless condition
end

begin
  session.visit("/backoffice/resources/external_customers?per_page=10")
  session.assert_selector("table.rk-index-table tbody tr", count: 10)
  verify(session.evaluate_script("!!window.Turbo && window.Turbo.session.drive"),
    "Turbo Drive did not load under enforced CSP")
  verify(session.evaluate_script("!!window.Stimulus"),
    "Stimulus did not load under enforced CSP")
  session.execute_script("document.querySelector('main').setAttribute('data-controller', 'rekorra-probe')")
  session.assert_selector("main[data-rk-probe-connected='true']")
  session.assert_no_text("Foreign Tenant Confidential")
  session.execute_script("window.__rekorraExternalVisits = 0; document.addEventListener('turbo:load', () => window.__rekorraExternalVisits++)")

  # Network asset requests must be served by this host's actual HTTP server.
  base_url = URI(session.current_url)
  urls = session.evaluate_script(<<~JS)
    Array.from(document.querySelectorAll("link[href], script[src]"))
      .map(element => element.href || element.src)
      .filter(url => url.includes("/assets/rekorra/"))
  JS
  verify(urls.any? { |url| url.include?("/rekorra/application") },
    "Missing CSS asset request")
  verify(urls.any? { |url| url.include?("/rekorra/index") },
    "Missing index JavaScript request")
  verify(urls.any? { |url| url.include?("/rekorra/associations") },
    "Missing association JavaScript request")
  urls.each do |url|
    asset_uri = URI(url)
    verify(asset_uri.host == base_url.host && asset_uri.port == base_url.port,
      "Asset URL points to a different host")
    served = Net::HTTP.get_response(asset_uri)
    verify(served.code == "200" && !served.body.empty?,
      "Asset #{url} is not served from host HTTP")
  end

  session.click_link("Next")
  session.assert_text("Page 2")
  verify(session.evaluate_script("window.__rekorraExternalVisits >= 1"),
    "Pagination replaced the JS document instead of using Turbo")
  session.go_back
  session.assert_text("Page 1")
  verify(session.evaluate_script("window.__rekorraExternalVisits >= 2"),
    "Browser history was not handled by Turbo")
  verify(session.evaluate_script("!document.querySelector('[data-rk-index]').dataset.loading"),
    "Index is busy after Turbo history restoration")
  puts "PASS #{stack}: external host actual Turbo navigation, back and static HTTP assets"

  session.visit("/backoffice/resources/external_orders")
  session.click_link("New record")
  session.assert_selector("form.rk-form")
  session.fill_in("record[number]", with: "E2E-EXTERNAL-001")
  session.fill_in("record[status]", with: "pending")
  session.fill_in("association_q[external_customer_id]", with: "Exceptional Late")
  session.within("form[data-rk-association-lookup]") { session.click_button("Find options") }
  session.assert_selector("select[name='record[external_customer_id]'] option[value='#{late.id}']")
  verify(session.find("input[name='record[number]']").value == "E2E-EXTERNAL-001",
    "Association lookup erased unsaved form draft")
  session.find("select[name='record[external_customer_id]']").find(
    "option[value='#{late.id}']").select_option
  session.within("form.rk-form") { session.click_button("Create") }
  session.assert_text("E2E-EXTERNAL-001")
  created = ExternalOrder.find_by!(number: "E2E-EXTERNAL-001")
  verify(created.external_customer_id == late.id,
    "Submitted record lost selected customer")
  puts "PASS #{stack}: real Turbo forms and draft-safe association lookup"

  puts "PASS #{stack}: installed-gem browser CSP + Turbo/Stimulus + HTTP assets"
ensure
  session.driver.quit
end
