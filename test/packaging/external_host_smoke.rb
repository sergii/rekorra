# frozen_string_literal: true

# Run OUTSIDE the repository after building and installing the .gem.
# Deliberately no require_relative of Rekorra sources, no path Gemfile,
# no pre-existing demo Rails application.
require "rubygems"
require "pathname"
require "fileutils"
require "rack/mock"
require "rails/all"
require "propshaft"
require "propshaft/railtie"
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
