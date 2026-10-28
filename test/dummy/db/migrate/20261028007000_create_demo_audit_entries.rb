# frozen_string_literal: true

class CreateDemoAuditEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :demo_audit_entries do |t|
      t.string :tenant_key, null: false, limit: 128
      t.string :actor_key, null: false, limit: 128
      t.string :record_type, null: false, limit: 120
      t.string :record_id, null: false, limit: 128
      t.string :action, null: false, limit: 20
      t.string :request_id, null: false, limit: 128
      t.datetime :occurred_at, null: false
    end
    add_index :demo_audit_entries, %i[tenant_key record_type record_id occurred_at],
      name: "index_demo_audit_entries_on_scope_and_time"
    add_index :demo_audit_entries, :request_id
  end
end
