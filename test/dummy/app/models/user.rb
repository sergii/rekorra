# frozen_string_literal: true

class User < ApplicationRecord
  belongs_to :organization
  validates :name, :email, :status, :role, presence: true
  validates :email, uniqueness: { scope: :organization_id }
end
