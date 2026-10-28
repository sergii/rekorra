# frozen_string_literal: true
# Isolated production host from separately installed gem.
require "rubygems"
require "pathname"
require "fileutils"
require "rails/all"
require "rake"

stack = ENV.fetch("REKORRA_ASSET_STACK")
abort "Unknown stack" unless %w[propshaft sprockets].include?(stack)
if stack == "propshaft"
  require "propshaft"
  require "propshaft/railtie"
else
  require "sprockets/railtie"
end
require "rekorra"

spec = Gem::Specification.find_by_name("rekorra")
abort "Loaded repository checkout" if spec.full_gem_path.start_with?(ENV.fetch("GITHUB_WORKSPACE"))
FileUtils.mkdir_p("config")
File.write("config/database.yml", "production:\n  adapter: sqlite3\n  database: ':memory:'\n")
if stack == "sprockets"
  FileUtils.mkdir_p("app/assets/config")
  File.write("app/assets/config/manifest.js", "//= link rekorra/application.css\n//= link rekorra/index.js\n//= link rekorra/associations.js\n")
end

module RekorraProductionAssetsHost
  class Application < Rails::Application
    config.root = Pathname.new(Dir.pwd)
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = "production-assets-ci-only-" * 4
    config.assets.compile = false
    config.assets.digest = true if config.assets.respond_to?(:digest=)
    config.hosts.clear
  end
end

app = RekorraProductionAssetsHost::Application
app.initialize!
app.load_tasks
Rake::Task["assets:precompile"].invoke

root = app.root.join("public/assets")
abort "Missing compiled public/assets directory" unless root.directory?
{
  "rekorra/application" => [".css", "--rk-bg"],
  "rekorra/index" => [".js", "data-rk-index"],
  "rekorra/associations" => [".js", "data-rk-association-lookup"]
}.each do |logical, (ext, marker)|
  filename = File.basename(logical)
  matches = Dir.glob(root.join("**/#{filename}-*#{ext}").to_s)
  abort "Missing fingerprinted #{logical}#{ext}" if matches.empty?
  abort "Missing #{logical} contents" unless matches.any? { |path| File.read(path).include?(marker) }
  puts "PASS #{stack}: #{logical}"
end
puts "PASS: #{stack} compiled all three production Rekorra assets"
