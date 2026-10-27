# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :status, null: false, default: "active"
      t.string :role, null: false, default: "member"
      t.boolean :verified, null: false, default: false
      t.timestamps
    end
    add_index :users, %i[organization_id email], unique: true
    add_index :users, %i[organization_id status id]
    add_index :users, %i[organization_id role created_at id]
  end
end
