# frozen_string_literal: true

class CreateDemoDomain < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |table|
      table.string :slug, null: false
      table.string :name, null: false
      table.timestamps
    end
    add_index :organizations, :slug, unique: true

    create_table :customers do |table|
      table.references :organization, null: false, foreign_key: true
      table.string :name, null: false
      table.string :email, null: false
      table.timestamps
    end
    add_index :customers, %i[organization_id email], unique: true

    create_table :orders do |table|
      table.references :customer, null: false, foreign_key: true
      table.string :number, null: false
      table.string :status, null: false, default: "pending"
      table.integer :total_cents, null: false, default: 0
      table.timestamps
    end
    add_index :orders, :number, unique: true

    create_table :payments do |table|
      table.references :order, null: false, foreign_key: true
      table.string :status, null: false, default: "pending"
      table.integer :amount_cents, null: false, default: 0
      table.timestamps
    end
  end
end
