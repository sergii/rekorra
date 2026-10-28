# frozen_string_literal: true

# Host-only lease state lives in the primary DB with the outbox intent.
class AddWorkerOutboxDispatchLeases < ActiveRecord::Migration[8.0]
  def change
    add_column :worker_outbox_events, :lease_token, :string
    add_column :worker_outbox_events, :lease_expires_at, :datetime
    add_column :worker_outbox_events, :next_attempt_at, :datetime
    add_column :worker_outbox_events, :dispatch_attempts, :integer, null: false, default: 0
    add_column :worker_outbox_events, :last_dispatcher_pid, :integer
    add_column :worker_outbox_events, :last_failure_kind, :string
    add_index :worker_outbox_events, [:status, :next_attempt_at, :lease_expires_at],
      name: "index_worker_outbox_events_for_dispatch"
  end
end
