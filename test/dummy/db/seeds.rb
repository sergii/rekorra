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
  User.insert_all(rows, unique_by: :index_users_on_organization_id_and_email)
end
