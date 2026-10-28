# frozen_string_literal: true

class CreateWorkerOutboxReviewDecisions < ActiveRecord::Migration[8.0]
  def change
    create_table :worker_outbox_review_decisions do |t|
      t.references :worker_outbox_event, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :actor_key, null: false
      t.string :reason, null: false
      t.timestamps
    end
  end
end
