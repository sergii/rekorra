# frozen_string_literal: true

class CreateWorkerRecoveryOperations < ActiveRecord::Migration[8.0]
  def change
    create_table :worker_recovery_effects do |t|
      t.references :organization, null: false
      t.references :order, null: false
      t.string :idempotency_key, null: false
      t.datetime :applied_at, null: false
      t.timestamps
    end
    add_index :worker_recovery_effects, [:organization_id, :idempotency_key],
      unique: true, name: "index_worker_recovery_effects_on_tenant_and_key"

    create_table :worker_recovery_decisions do |t|
      t.references :order, null: false
      t.string :active_job_id, null: false
      t.string :actor_key, null: false
      t.string :reason, null: false
      t.string :action, null: false
      t.timestamps
    end
    add_index :worker_recovery_decisions, :active_job_id, unique: true
  end
end
