# frozen_string_literal: true

class CreateCrmDemo < ActiveRecord::Migration[8.0]
  def change
    create_table :crm_leads do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :reference, null: false
      t.string :company_name, null: false
      t.string :contact_email, null: false
      t.string :stage, null: false
      t.string :assigned_to, null: false
      t.date :follow_up_on
      t.timestamps
    end
    add_index :crm_leads, %i[organization_id reference], unique: true
    add_index :crm_leads, %i[organization_id stage id]

    create_table :crm_onboardings do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :reference, null: false
      t.string :company_name, null: false
      t.string :stage, null: false
      t.string :health, null: false
      t.string :assigned_to, null: false
      t.datetime :stage_entered_at, null: false
      t.string :finding
      t.timestamps
    end
    add_index :crm_onboardings, %i[organization_id reference], unique: true
    add_index :crm_onboardings, %i[organization_id stage health id]
  end
end
