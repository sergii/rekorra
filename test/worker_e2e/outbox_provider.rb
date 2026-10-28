# frozen_string_literal: true

# Independent localhost HTTP provider with its OWN PostgreSQL database.
# Simulates a remote effect committed before the HTTP response is lost.
require "socket"
require "pg"
require "json"
require "uri"
require "fileutils"

db = PG.connect(ENV.fetch("REKORRA_EXTERNAL_DATABASE_URL"))
port_file = ENV.fetch("REKORRA_PROVIDER_PORT_FILE")
crash_key = ENV.fetch("REKORRA_PROVIDER_CRASH_KEY", "none")
server = TCPServer.new("127.0.0.1", 0)
FileUtils.mkdir_p(File.dirname(port_file))
File.write(port_file, server.addr[1].to_s)
STDOUT.sync = true
puts "Provider listening on #{server.addr[1]}, crash_key=#{crash_key}"

def reply(client, status, payload)
  body = JSON.generate(payload)
  client.write "HTTP/1.1 #{status}\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
end

loop do
  client = server.accept
  begin
    line = client.gets
    next unless line
    method, target, = line.split(" ", 3)
    headers = {}
    while (line = client.gets)
      break if line == "\r\n" || line == "\n"
      k, v = line.split(":", 2)
      headers[k.downcase] = v.to_s.strip
    end
    if method == "POST" && target == "/deliver"
      length = Integer(headers.fetch("content-length", "0"))
      raise "Invalid length" unless length.between?(1, 4_096)
      body = JSON.parse(client.read(length))
      key = headers.fetch("idempotency-key")
      raise "Invalid key" unless key.match?(/\A[0-9]+:[a-zA-Z0-9][a-zA-Z0-9:_-]{0,99}\z/)
      raise "Missing tenant" unless body.fetch("organization_id").to_s == key.split(":", 2).first

      db.exec("BEGIN")
      begin
        result = db.exec_params(<<~SQL, [key])
          INSERT INTO provider_receipts(operation_key, receipt, requests, ack_dropped)
          VALUES ($1, 'provider-' || substr(md5($1), 1, 12), 1, FALSE)
          ON CONFLICT(operation_key) DO UPDATE SET requests = provider_receipts.requests + 1
          RETURNING receipt, ack_dropped
        SQL
        receipt = result[0].fetch("receipt")
        drop = key == crash_key && result[0].fetch("ack_dropped") == "f"
        db.exec_params("UPDATE provider_receipts SET ack_dropped = TRUE WHERE operation_key = $1", [key]) if drop
        db.exec("COMMIT")
      rescue Exception
        db.exec("ROLLBACK")
        raise
      end
      if drop
        puts "Provider COMMITTED #{key}; deliberately dying before acknowledgment"
        Process.kill("KILL", Process.pid)
      end
      reply(client, "200 OK", { key: key, receipt: receipt })
    elsif method == "GET" && target.start_with?("/receipt?")
      query = URI.decode_www_form(URI.parse(target).query.to_s).to_h
      key = query.fetch("key")
      result = db.exec_params("SELECT receipt FROM provider_receipts WHERE operation_key = $1", [key])
      if result.ntuples == 0
        reply(client, "404 Not Found", { error: "not_found" })
      else
        reply(client, "200 OK", { key: key, receipt: result[0].fetch("receipt") })
      end
    else
      reply(client, "404 Not Found", { error: "unknown_route" })
    end
  rescue StandardError => e
    warn "Provider request error #{e.class}"
    reply(client, "400 Bad Request", { error: "invalid_request" }) rescue nil
  ensure
    client.close rescue nil
  end
end
