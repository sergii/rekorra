# frozen_string_literal: true

module Rekorra
  module Jobs
    # Safe, provider-independent projection. Never includes serialized arguments
    # or raw exception/backtrace content.
    Item = Struct.new(:id, :name, :queue, :status, :created_at, :scheduled_at,
      :finished_at, keyword_init: true)
  end
end
