# frozen_string_literal: true

# The outbox lives in the SAME primary database as the business mutation.
class CreateWorkerOutboxEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :worker_outbox_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.string :operation_key, null: false, limit: 100
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.string :provider_receipt
      t.datetime :last_attempt_at
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :worker_outbox_events, [:organization_id, :operation_key],
      unique: true, name: "index_worker_outbox_events_on_tenant_and_key"
    add_index :worker_outbox_events, [:status, :created_at]
  end
end
