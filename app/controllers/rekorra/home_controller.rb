# frozen_string_literal: true

module Rekorra
  class HomeController < ApplicationController
    def index
      authorize!(nil, :access?)
    end
  end
end
