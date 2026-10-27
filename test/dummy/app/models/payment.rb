# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order

  validates :status, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
