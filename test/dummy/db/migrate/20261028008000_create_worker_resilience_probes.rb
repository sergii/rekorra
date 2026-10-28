# frozen_string_literal: true

class CreateWorkerResilienceProbes < ActiveRecord::Migration[8.0]
  def change
    create_table :worker_resilience_probes do |t|
      t.string :token, null: false
      t.integer :started_pid
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :execution_count, null: false, default: 0
      t.timestamps
    end
    add_index :worker_resilience_probes, :token, unique: true
  end
end
