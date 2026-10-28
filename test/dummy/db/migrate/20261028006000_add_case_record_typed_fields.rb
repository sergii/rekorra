# frozen_string_literal: true

class AddCaseRecordTypedFields < ActiveRecord::Migration[8.0]
  def change
    add_column :case_records, :flagged, :boolean, default: false, null: false
    add_column :case_records, :due_on, :date
    add_column :case_records, :estimated_hours, :decimal, precision: 8, scale: 2
    add_column :case_records, :reviewed_at, :datetime
    add_column :case_records, :notes, :text
  end
end
