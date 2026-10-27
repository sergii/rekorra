# frozen_string_literal: true

# Host-owned, explicit mapping. The Gem does not read serialized job arguments.
class DemoJobLink < ApplicationRecord
  belongs_to :order
  validates :active_job_id, presence: true, uniqueness: true
  validates :job_class_name, presence: true
end
