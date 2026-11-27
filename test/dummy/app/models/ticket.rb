# frozen_string_literal: true

class Ticket < ApplicationRecord
  has_paper_trail on: %i[create update destroy]
  belongs_to :customer
  has_many :demo_job_links, dependent: :destroy
  has_many :interactions, dependent: :restrict_with_error

  validates :number, :status, presence: true
  validates :number, uniqueness: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
