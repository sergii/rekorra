# frozen_string_literal: true

class AddDemoJobLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :receipt_generated_at, :datetime

    create_table :demo_job_links do |t|
      t.references :order, null: false, foreign_key: true
      t.string :active_job_id, null: false
      t.string :job_class_name, null: false
      t.timestamps
    end
    add_index :demo_job_links, :active_job_id, unique: true
  end
end
