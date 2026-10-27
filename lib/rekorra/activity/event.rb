# frozen_string_literal: true

module Rekorra
  module Activity
    Change = Struct.new(:field, :before, :after, keyword_init: true)
    Event = Struct.new(:kind, :at, :actor, :changes, keyword_init: true)
  end
end
