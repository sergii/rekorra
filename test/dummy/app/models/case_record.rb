# frozen_string_literal: true

class CaseRecord < ApplicationRecord
  belongs_to :organization
  enum :state, { open: "open", reviewing: "reviewing", closed: "closed" }
  validates :title, presence: true
end
