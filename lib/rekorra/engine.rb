# frozen_string_literal: true

module Rekorra
  class Engine < ::Rails::Engine
    isolate_namespace Rekorra

    initializer "rekorra.assets" do |app|
      # Propshaft discovers gem assets; Sprockets needs explicit precompilation.
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += ["rekorra/application.css", "rekorra/index.js", "rekorra/associations.js"]
      end
    end
  end
end
