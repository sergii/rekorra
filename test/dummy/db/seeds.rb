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

ticket_a = Ticket.find_or_create_by!(number: "ACME-1001") do |ticket|
  ticket.customer = alice
  ticket.status = "pending"
  ticket.estimated_minutes = 25000
end
# Demonstrate a real change event while keeping the seeded end state stable.
ticket_a.update!(status: "completed") unless ticket_a.status == "completed"

ticket_a.update!(
  support_issue_id: "10024",
  support_issue_key: "SUP-482",
  trace_id: "4bf92f3577b34da6a3ce929d0e0e4736"
)
ticket_b = Ticket.find_or_create_by!(number: "ACME-1002") do |ticket|
  ticket.customer = bob
  ticket.status = "pending"
  ticket.estimated_minutes = 7800
end
Ticket.find_or_create_by!(number: "GLOBEX-9001") do |ticket|
  ticket.customer = other
  ticket.status = "completed"
  ticket.estimated_minutes = 9900
end
Interaction.find_or_create_by!(ticket: ticket_a, status: "logged") { |interaction| interaction.duration_minutes = 25000 }
# Intentionally inconsistent sample, so the Findings panel has an example.
Interaction.find_or_create_by!(ticket: ticket_b, status: "logged") { |interaction| interaction.duration_minutes = 7800 }

puts "Rekorra demo records ready: login acme or globex with REKORRA_DEMO_PASSWORD"

# Enqueue exactly one demonstration job for the first ticket.
# It remains queued until the demo runs a Solid Queue worker.
unless ticket_a.demo_job_links.exists?
  job = TicketSummaryJob.perform_later(ticket_a.id)
  if job&.successfully_enqueued?
    DemoJobLink.create!(ticket: ticket_a, active_job_id: job.job_id,
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
