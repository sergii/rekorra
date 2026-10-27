# frozen_string_literal: true

module Rekorra
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NotAuthenticated < Error; end
  class NotAuthorized < Error; end
end
