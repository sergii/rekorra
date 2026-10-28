# frozen_string_literal: true

# Run OUTSIDE the repository after building and installing the .gem.
# Deliberately no require_relative of Rekorra sources, no path Gemfile,
# no pre-existing demo Rails application.
require "rubygems"
require "pathname"
require "fileutils"
require "rack/mock"
require "rails/all"
stack = ENV.fetch("REKORRA_SMOKE_STACK", "propshaft")
abort "Unexpected asset stack" unless %w[propshaft sprockets propshaft-hotwire sprockets-hotwire].include?(stack)
sprockets = stack.start_with?("sprockets")
hotwire = stack.end_with?("-hotwire")
if sprockets
  require "sprockets/railtie"
else
  require "propshaft"
  require "propshaft/railtie"
end
if hotwire
  require "importmap-rails"
  require "turbo-rails"
  require "stimulus-rails"
end
require "rekorra"

spec = Gem::Specification.find_by_name("rekorra")
source_root = File.expand_path("../..", __dir__)
if spec.full_gem_path.start_with?("#{source_root}/")
  abort "Smoke must load the installed gem, not the repository checkout"
end

%w[
  lib/rekorra.rb
  lib/rekorra/engine.rb
  config/routes.rb
  app/controllers/rekorra/application_controller.rb
  app/views/rekorra/resources/index.html.erb
  app/assets/stylesheets/rekorra/application.css
  app/assets/javascripts/rekorra/index.js
  app/assets/javascripts/rekorra/associations.js
].each do |file|
  unless File.file?(File.join(spec.full_gem_path, file))
    abort "Built gem is missing #{file}"
  end
end

# A real host has its own database configuration, even if the smoke request
# does not query models. Keep it independent of test/dummy.
FileUtils.mkdir_p("config")
File.write("config/database.yml", <<~YAML)
  development:
    adapter: sqlite3
    database: ":memory:"
  test:
    adapter: sqlite3
    database: ":memory:"
YAML

if sprockets
  FileUtils.mkdir_p("app/assets/config")
  File.write("app/assets/config/manifest.js", <<~JS)
    //= link rekorra/application.css
    //= link rekorra/index.js
    //= link rekorra/associations.js
  JS
end

if hotwire
  File.write("config/importmap.rb", <<~RUBY)
    pin "@hotwired/turbo-rails", to: "turbo.min.js"
    pin "@hotwired/stimulus", to: "stimulus.min.js"
  RUBY
end

module RekorraExternalPackagingHost
  class Application < ::Rails::Application
    config.root = Pathname.new(Dir.pwd)
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = "external-host-packaging-smoke-only-" * 3
    config.hosts.clear
    config.session_store :cookie_store, key: "_rekorra_external_smoke"
  end
end

if sprockets
  RekorraExternalPackagingHost::Application.config.assets.compile = true
  RekorraExternalPackagingHost::Application.config.assets.unknown_asset_fallback = false
end

Rekorra.configure do |config|
  config.authenticate_with = ->(_controller) { :packaging_test_actor }
  config.authorize_with = ->(_actor, _subject, action) { action == :access? }
  config.scope_with = ->(_actor, model) { model.none }
end

app = RekorraExternalPackagingHost::Application
app.initialize!
app.routes.draw { mount Rekorra::Engine => "/backoffice" }

response = Rack::MockRequest.new(app).get("/backoffice", "HTTP_HOST" => "localhost")
unless response.status == 200 && response.body.include?("Rekorra engine is mounted")
  abort "Installed engine HTTP boot failed: status=#{response.status}, body=#{response.body[0, 400].inspect}"
end

puts "External host boot OK: installed #{spec.name} #{spec.version} from #{spec.full_gem_path}"
puts "Mounted GET /backoffice => HTTP #{response.status}; packaged assets verified"


# Following the generated layout links detects missing pipeline registration,
# not just missing files in the gem archive.
request = Rack::MockRequest.new(app)
{
  "rekorra/application" => ["css", "--rk-bg"],
  "rekorra/index" => ["js", "data-rk-index"],
  "rekorra/associations" => ["js", "data-rk-association-lookup"]
}.each do |logical, (extension, marker)|
  source = Regexp.escape(logical)
  pattern = %r{(?:href|src)="([^"]*/assets/#{source}(?:-[a-f0-9]+)?\.#{extension}(?:\?[^"]*)?)"}
  match = response.body.match(pattern)
  abort "#{stack}: missing #{logical}.#{extension} link" unless match
  asset = request.get(match[1].split("?").first, "HTTP_HOST" => "localhost")
  unless asset.status == 200 && asset.body.include?(marker)
    abort "#{stack}: invalid asset #{match[1]} HTTP #{asset.status}"
  end
end

if hotwire
  abort "Turbo engine was not loaded" unless defined?(Turbo::Engine)
  abort "Stimulus engine was not loaded" unless defined?(Stimulus::Engine)
end
puts "#{stack}: packaged CSS and JavaScript served successfully"
