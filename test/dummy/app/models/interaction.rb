# frozen_string_literal: true

class Interaction < ApplicationRecord
  belongs_to :ticket

  validates :status, presence: true
  validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
