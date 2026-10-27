# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :customers, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
end
