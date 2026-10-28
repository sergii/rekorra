# frozen_string_literal: true

class CreateCaseRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :case_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :state, null: false, default: "open"
      t.timestamps
    end
    add_index :case_records, %i[organization_id state id]
  end
end
