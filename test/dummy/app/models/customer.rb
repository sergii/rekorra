# frozen_string_literal: true

class Customer < ApplicationRecord
  belongs_to :organization
  has_many :orders, dependent: :restrict_with_error

  validates :name, :email, presence: true
  validates :email, uniqueness: { scope: :organization_id }
end
