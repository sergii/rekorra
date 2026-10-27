# frozen_string_literal: true

namespace :demo do
  desc "Seed up to N Users for large-model pagination QA (default: 50000)"
  task :seed_users, [:count] => :environment do |_task, args|
    count = Integer(args[:count] || 50_000)
    abort "count must be between 1 and 100000" unless count.between?(1, 100_000)
    org = Organization.find_by!(slug: "acme")
    now = Time.current
    (1..count).each_slice(1000) do |numbers|
      records = numbers.map do |n|
        {
          organization_id: org.id,
          name: "Large User #{format('%06d', n)}",
          email: "large-user-#{format('%06d', n)}@example.test",
          status: n.even? ? "active" : "suspended",
          role: n % 20 == 0 ? "admin" : "member",
          verified: n % 3 == 0,
          created_at: now - n.minutes,
          updated_at: now
        }
      end
      User.insert_all(records, unique_by: :index_users_on_organization_id_and_email)
    end
    puts "Demo users: #{org.users.count}"
  end
end
