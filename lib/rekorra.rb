# frozen_string_literal: true

require "rails/engine"
require_relative "rekorra/version"
require_relative "rekorra/errors"
require_relative "rekorra/configuration"

module Rekorra
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end

require_relative "rekorra/engine"
