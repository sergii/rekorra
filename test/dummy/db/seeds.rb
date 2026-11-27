# frozen_string_literal: true

acme = Organization.find_or_create_by!(slug: "acme") { |organization| organization.name = "Acme Ltd" }
globex = Organization.find_or_create_by!(slug: "globex") { |organization| organization.name = "Globex Ltd" }

alice = Customer.find_or_create_by!(organization: acme, email: "alice@example.test") do |customer|
  customer.name = "Alice Miller"
end
bob = Customer.find_or_create_by!(organization: acme, email: "bob@example.test") do |customer|
  customer.name = "Bob Smith"
end
other = Customer.find_or_create_by!(organization: globex, email: "hidden@example.test") do |customer|
  customer.name = "Globex Customer"
end

order_a = Order.find_or_create_by!(number: "ACME-1001") do |order|
  order.customer = alice
  order.status = "pending"
  order.total_cents = 25000
end
# Demonstrate a real change event while keeping the seeded end state stable.
order_a.update!(status: "paid") unless order_a.status == "paid"

order_a.update!(
  support_issue_id: "10024",
  support_issue_key: "BILL-482",
  trace_id: "4bf92f3577b34da6a3ce929d0e0e4736"
)
order_b = Order.find_or_create_by!(number: "ACME-1002") do |order|
  order.customer = bob
  order.status = "pending"
  order.total_cents = 7800
end
Order.find_or_create_by!(number: "GLOBEX-9001") do |order|
  order.customer = other
  order.status = "paid"
  order.total_cents = 9900
end
Payment.find_or_create_by!(order: order_a, status: "captured") { |payment| payment.amount_cents = 25000 }
# Intentionally inconsistent sample, so the Findings panel has an example.
Payment.find_or_create_by!(order: order_b, status: "captured") { |payment| payment.amount_cents = 7800 }

puts "Rekorra demo records ready: login acme or globex with REKORRA_DEMO_PASSWORD"

# Enqueue exactly one demonstration job for the first order.
# It remains queued until the demo runs a Solid Queue worker.
unless order_a.demo_job_links.exists?
  job = OrderReceiptJob.perform_later(order_a.id)
  if job&.successfully_enqueued?
    DemoJobLink.create!(order: order_a, active_job_id: job.job_id,
      job_class_name: job.class.name)
  end
end

# A small default dataset makes pagination visible in the ordinary Users Index.
# Use `rake demo:seed_users[50000]` for an opt-in large dataset.
if acme.users.count < 65
  now = Time.current
  rows = (1..65).map do |n|
    {
      organization_id: acme.id,
      name: "Demo User #{format('%05d', n)}",
      email: "demo-user-#{format('%05d', n)}@example.test",
      status: n % 7 == 0 ? "suspended" : "active",
      role: n % 10 == 0 ? "admin" : "member",
      verified: n.even?,
      created_at: now - n.days,
      updated_at: now
    }
  end
  User.insert_all(rows)
end

# CRM dogfooding: repeatable synthetic records; never real customer data.
[
  ["LEAD-001", "Pine Studio", "new_lead", "Jamie", 1],
  ["LEAD-002", "Northwind Design", "contacted", "Morgan", -2],
  ["LEAD-003", "Cedar Labs", "qualified", "Jamie", 3],
  ["LEAD-004", "Orbit Garden", "won", "Morgan", 5]
].each do |reference, company, stage, assignee, days|
  Crm::Lead.find_or_create_by!(organization: acme, reference: reference) do |lead|
    lead.assign_attributes(company_name: company, contact_email: "#{reference.downcase}@example.test",
      stage: stage, assigned_to: assignee, follow_up_on: Date.current + days)
  end
end

[
  ["ONB-001", "Pine Studio", "started", "healthy", "Jamie", 2.minutes, nil],
  ["ONB-002", "Northwind Design", "dispatched", "unknown", "Jamie", 45.minutes, "No server response; outcome unknown"],
  ["ONB-003", "Cedar Labs", "dispatched", "failed", "Morgan", 2.hours, "Provider explicitly rejected request"],
  ["ONB-004", "Orbit Garden", "awaiting_confirmation", "overdue", "Jamie", 8.days, "Confirmation webhook missing"],
  ["ONB-005", "Maple Works", "confirmed", "healthy", "Morgan", 1.day, nil]
].each do |reference, company, stage, health, assignee, age, finding|
  Crm::Onboarding.find_or_create_by!(organization: acme, reference: reference) do |record|
    record.assign_attributes(company_name: company, stage: stage, health: health,
      assigned_to: assignee, stage_entered_at: Time.current - age, finding: finding)
  end
end

Crm::Lead.find_or_create_by!(organization: globex, reference: "LEAD-001") do |lead|
  lead.assign_attributes(company_name: "Globex Private CRM", contact_email: "globex-crm@example.test",
    stage: "contacted", assigned_to: "Taylor")
end
