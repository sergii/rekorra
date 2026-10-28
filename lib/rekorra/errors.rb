# frozen_string_literal: true

module Rekorra
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NotAuthenticated < Error; end
  class NotAuthorized < Error; end
  class UnknownResource < Error; end
  class InvalidCursor < Error; end
end
