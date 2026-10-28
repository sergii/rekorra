# frozen_string_literal: true

# Host-owned model, not a Rekorra Engine table.
class DemoAuditEntry < ApplicationRecord
  validates :tenant_key, :actor_key, :record_type, :record_id,
    :request_id, :action, :occurred_at, presence: true
end
