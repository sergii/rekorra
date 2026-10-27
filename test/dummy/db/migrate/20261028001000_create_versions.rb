# frozen_string_literal: true

# Demo host owns the PaperTrail schema. Rekorra does not create tables.
class CreateVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :versions do |t|
      t.string :item_type, null: false
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.json :object
      t.json :object_changes
      t.datetime :created_at, null: false
    end
    add_index :versions, %i[item_type item_id]
  end
end
