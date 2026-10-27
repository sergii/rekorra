# frozen_string_literal: true

require_relative "lib/rekorra/version"

Gem::Specification.new do |spec|
  spec.name = "rekorra"
  spec.version = Rekorra::VERSION
  spec.summary = "Rails-native, modular administration and back-office engine"
  spec.description = "A server-rendered Rails Engine for building secure back-office workspaces."
  spec.authors = ["Rekorra contributors"]
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["app/**/*", "config/routes.rb", "lib/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
  spec.add_dependency "railties", ">= 8.0", "< 9.0"
  spec.add_dependency "actionpack", ">= 8.0", "< 9.0"
  spec.add_dependency "activerecord", ">= 8.0", "< 9.0"
  spec.add_dependency "activesupport", ">= 8.0", "< 9.0"
  spec.metadata["rubygems_mfa_required"] = "true"
end
