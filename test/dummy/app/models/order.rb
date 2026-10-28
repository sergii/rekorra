# frozen_string_literal: true

class Order < ApplicationRecord
  enum :status, { pending: "pending", paid: "paid", fulfilled: "fulfilled" }
  has_paper_trail on: %i[create update destroy]
  belongs_to :customer
  has_many :demo_job_links, dependent: :destroy
  has_many :payments, dependent: :restrict_with_error

  validates :number, :status, presence: true
  validates :number, uniqueness: true
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
