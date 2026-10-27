# frozen_string_literal: true

# Host-owned domain rule. The Order has already been scoped and authorized by
# Rekorra. Its payments are reached only through the Order association.
class PaidButPending
  def evaluate(record:)
    return nil unless record.is_a?(Order) && record.status == "pending"
    return nil unless record.total_cents.positive?

    captured_cents = record.payments.where(status: "captured").sum(:amount_cents)
    return nil if captured_cents < record.total_cents

    Rekorra::Findings::Finding.new(
      code: "paid_but_pending", severity: "warning",
      title: "Payment captured, order still pending",
      description: "Captured payments cover the order total, but the order has not advanced beyond pending.",
      evidence: [
        Rekorra::Findings::Evidence.new(label: "Order status", value: record.status),
        Rekorra::Findings::Evidence.new(label: "Order total (cents)", value: record.total_cents),
        Rekorra::Findings::Evidence.new(label: "Captured (cents)", value: captured_cents)
      ]
    )
  end
end
