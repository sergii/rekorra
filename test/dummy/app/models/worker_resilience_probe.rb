# frozen_string_literal: true
class WorkerResilienceProbe < ApplicationRecord
  validates :token, presence: true, uniqueness: true
end
