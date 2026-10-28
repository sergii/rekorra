# frozen_string_literal: true

# Independent scanner OS process for PostgreSQL CI. No inline job adapter.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
STDOUT.sync = true
dispatcher = WorkerOutboxDispatcher.new(
  endpoint: ENV.fetch("REKORRA_DISPATCH_ENDPOINT"),
  allowed_hosts: [], allow_test_http: true
)
if ENV["REKORRA_DISPATCH_HOLD_AFTER_CLAIM"] == "1"
  claim = dispatcher.claim_one!(lease_seconds: 2)
  abort "No claim to hold" unless claim
  puts "LEASED event=#{claim.event_id} token=#{claim.token} pid=#{Process.pid}"
  sleep 30
else
  if barrier = ENV["REKORRA_DISPATCH_BARRIER"]
    File.write("#{barrier}.#{Process.pid}", "ready")
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    until File.exist?(barrier)
      abort "Barrier timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
  end
  70.times do
    result = dispatcher.dispatch_once!
    puts "DISPATCH #{result} pid=#{Process.pid}"
    break if result == :idle
    sleep 0.035
  end
end
