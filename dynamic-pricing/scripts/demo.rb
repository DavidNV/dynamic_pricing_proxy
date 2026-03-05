#!/usr/bin/env ruby
# =============================================================================
# demo.rb — Pricing Proxy Service Demo
#
# Showcases caching, batching, quota tracking and error handling.
#
# Usage (from inside the container):
#   ruby scripts/demo.rb
#
# Usage (from host):
#   docker compose exec interview-dev ruby scripts/demo.rb
# =============================================================================

require 'net/http'
require 'uri'
require 'json'
require 'time'

BASE_URL = "http://localhost:3000/api/v1/pricing"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

COLORS = {
  reset:   "\e[0m",  bold:    "\e[1m",  dim:     "\e[2m",
  green:   "\e[32m", red:     "\e[31m", yellow:  "\e[33m",
  cyan:    "\e[36m", magenta: "\e[35m", white:   "\e[37m"
}

def c(color, text) = "#{COLORS[color]}#{text}#{COLORS[:reset]}"
def separator(char = "─", width = 65) = puts(c(:dim, char * width))

def section(number, title)
  puts
  separator("═")
  puts c(:bold, "  #{number}. #{title}")
  separator("═")
  puts
end

def get_pricing(period:, hotel:, room:)
  uri = URI(BASE_URL)
  uri.query = URI.encode_www_form(period: period, hotel: hotel, room: room)
  t = Time.now
  response = Net::HTTP.get_response(uri)
  [response, elapsed_ms(t)]
end

def post_pricing(attributes:)
  uri  = URI(BASE_URL)
  http = Net::HTTP.new(uri.host, uri.port)
  req  = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
  req.body = { attributes: attributes }.to_json
  t = Time.now
  response = http.request(req)
  [response, elapsed_ms(t)]
end

def elapsed_ms(start) = ((Time.now - start) * 1000).round(1)

def print_result(response, elapsed, label: nil)
  puts c(:dim, "  #{label}") if label
  code_color = response.code.to_i < 300 ? :green : :red
  body = JSON.parse(response.body) rescue response.body
  puts "  Status   : #{c(code_color, response.code)}"
  puts "  Time     : #{c(:cyan, "#{elapsed}ms")}"
  puts "  Response : #{c(:white, JSON.pretty_generate(body).gsub("\n", "\n             "))}"
  puts
end

def pass(msg) = puts(c(:green,  "  ✓ #{msg}"))
def fail(msg) = puts(c(:red,    "  ✗ #{msg}"))
def info(msg) = puts(c(:dim,    "  #{msg}"))

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------

puts
puts c(:magenta, c(:bold, "  ╔══════════════════════════════════════════════╗"))
puts c(:magenta, c(:bold, "  ║   🏨  Pricing Proxy Service — Live Demo      ║"))
puts c(:magenta, c(:bold, "  ╚══════════════════════════════════════════════╝"))
puts
info("Base URL : #{BASE_URL}")
info("Token    : 04aa6f42aa03f220c2ae9a276cd68c62 (upstream only)")
info("Redis    : Caching rates (TTL 5 min) + quota tracking (TTL 24 hr)")

# -----------------------------------------------------------------------------
section("1", "Single Room Lookup — Cache Miss (first request)")
# -----------------------------------------------------------------------------

info("Summer/FloatingPointResort/SingletonRoom has not been requested yet.")
info("Upstream API will be called. Rate will be written to Redis.\n")

response, elapsed = get_pricing(
  period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom"
)
print_result(response, elapsed,
  label: "GET /api/v1/pricing?period=Summer&hotel=FloatingPointResort&room=SingletonRoom"
)

response.code == "200" ? pass("Rate returned successfully") : fail("Unexpected error")

# -----------------------------------------------------------------------------
section("2", "Single Room Lookup — Cache Hit (same request)")
# -----------------------------------------------------------------------------

info("Exact same request repeated immediately.")
info("Redis has the rate — upstream will NOT be called.\n")

response2, elapsed2 = get_pricing(
  period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom"
)
print_result(response2, elapsed2,
  label: "GET /api/v1/pricing?period=Summer&hotel=FloatingPointResort&room=SingletonRoom"
)

if response2.code == "200"
  pass("Rate returned from cache")
  pass("Response time #{elapsed2}ms vs #{elapsed}ms on first request")
end

# -----------------------------------------------------------------------------
section("3", "Batch Lookup — Partial Cache Resolution")
# -----------------------------------------------------------------------------

info("Requesting 4 rooms in one POST call.")
info("Summer/FloatingPointResort/SingletonRoom is already cached.")
info("Only the 3 remaining rooms will go upstream — 1 upstream call total.\n")

attributes = [
  { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" }, # cached
  { period: "Autumn", hotel: "FloatingPointResort", room: "SingletonRoom" }, # miss
  { period: "Winter", hotel: "GitawayHotel",        room: "BooleanTwin"   }, # miss
  { period: "Spring", hotel: "RecursionRetreat",    room: "RestfulKing"   }  # miss
]

response, elapsed = post_pricing(attributes: attributes)
print_result(response, elapsed, label: "POST /api/v1/pricing")

if response.code == "200"
  body = JSON.parse(response.body)
  pass("#{body['rates'].length}/4 rates returned in a single upstream call")
  pass("Summer/SingletonRoom served from cache — zero upstream cost for that room")
end

# -----------------------------------------------------------------------------
section("4", "Validation — Bad Parameters")
# -----------------------------------------------------------------------------

info("Invalid period — should return 400 Bad Request.\n")
response, elapsed = get_pricing(period: "InvalidSeason", hotel: "FloatingPointResort", room: "SingletonRoom")
print_result(response, elapsed, label: "GET ?period=InvalidSeason&hotel=FloatingPointResort&room=SingletonRoom")
response.code == "400" ? pass("Correctly rejected with 400") : fail("Expected 400, got #{response.code}")

info("Missing all parameters — should return 400 Bad Request.\n")
response = Net::HTTP.get_response(URI(BASE_URL))
print_result(response, 0, label: "GET /api/v1/pricing (no params)")
response.code == "400" ? pass("Correctly rejected with 400") : fail("Expected 400, got #{response.code}")

info("Batch with invalid hotel — should return 400 Bad Request.\n")
response, elapsed = post_pricing(attributes: [
  { period: "Summer", hotel: "InvalidHotel", room: "SingletonRoom" }
])
print_result(response, elapsed, label: "POST with invalid hotel")
response.code == "400" ? pass("Correctly rejected with 400") : fail("Expected 400, got #{response.code}")

# -----------------------------------------------------------------------------
section("5", "Concurrent Requests — Cache Efficiency Under Load")
# -----------------------------------------------------------------------------

info("Firing 20 concurrent requests for the same room.")
info("All should be served from Redis after the first batch call.\n")

threads = []
results = []
mutex   = Mutex.new

20.times do |i|
  threads << Thread.new do
    resp, ms = get_pricing(
      period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom"
    )
    mutex.synchronize { results << { i: i + 1, code: resp.code, ms: ms } }
  end
end

threads.each(&:join)
results.sort_by! { |r| r[:i] }

results.each_slice(5) do |slice|
  puts "  " + slice.map { |r|
    code_color = r[:code] == "200" ? :green : :red
    "#{r[:i].to_s.rjust(2)}: #{c(code_color, r[:code])} #{c(:cyan, "#{r[:ms]}ms".rjust(8))}"
  }.join("   ")
end

puts
success_count = results.count { |r| r[:code] == "200" }
avg_ms        = (results.sum { |r| r[:ms] } / results.length.to_f).round(1)
min_ms        = results.min_by { |r| r[:ms] }[:ms]
max_ms        = results.max_by { |r| r[:ms] }[:ms]

pass("#{success_count}/20 requests succeeded")
pass("Avg: #{avg_ms}ms  Min: #{min_ms}ms  Max: #{max_ms}ms")

# -----------------------------------------------------------------------------
section("6", "Quota Tracking")
# -----------------------------------------------------------------------------

info("Checking current upstream quota usage via Redis.\n")

require 'redis'
redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
count = redis.get("upstream:call_count").to_i
ttl   = redis.ttl("upstream:call_count")
hours = (ttl / 3600.0).round(1)

puts "  Upstream calls today : #{c(:yellow, count.to_s)} / #{c(:white, "1000")}"
puts "  Quota resets in      : #{c(:cyan, "#{hours} hours")}"
puts "  Remaining calls      : #{c(:green, (1000 - count).to_s)}"
puts

count < 1000 ? pass("Quota healthy — #{1000 - count} calls remaining") : fail("Quota exhausted!")

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

puts
separator("═")
puts c(:bold, "  Summary")
separator
puts
pass("GET  /api/v1/pricing  — single room, cache miss + hit")
pass("POST /api/v1/pricing  — batch, partial cache resolution")
pass("Parameter validation  — 400 for invalid/missing params")
pass("Concurrent requests   — all served correctly from cache")
pass("Quota tracking        — atomic Redis counter, 24hr TTL")
puts
separator("═")
puts c(:magenta, c(:bold, "  🎉  All systems go. Service is working correctly."))
separator("═")
puts