require "test_helper"

class RateCacheTest < ActiveSupport::TestCase
  VALID_PERIOD = "Summer"
  VALID_HOTEL  = "FloatingPointResort"
  VALID_ROOM   = "SingletonRoom"
  VALID_RATE   = { "period" => VALID_PERIOD, "hotel" => VALID_HOTEL, "room" => VALID_ROOM, "rate" => "15000" }.freeze

  def rate_cache_key
    "pricing:#{VALID_PERIOD}:#{VALID_HOTEL}:#{VALID_ROOM}"
  end

  setup do
    REDIS.del(rate_cache_key)
  end

  test "returns nil on a cache miss" do
    result = RateCache.fetch(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)
    assert_nil result
  end

  test "returns the cached rate after a write" do
    RateCache.write(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM, rate: VALID_RATE)
    result = RateCache.fetch(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)

    assert_equal VALID_RATE, result
  end

  test "returns nil after TTL expires" do
    RateCache.write(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM, rate: VALID_RATE, ttl: 1)
    sleep 1.1
    result = RateCache.fetch(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)

    assert_nil result
  end

  test "increments the quota counter on each upstream call" do
    REDIS.del("upstream:call_count")

    RateCache.increment_quota_counter
    RateCache.increment_quota_counter
    RateCache.increment_quota_counter

    assert_equal 3, RateCache.quota_count
  end

  test "detects when quota is exceeded" do
    REDIS.del("upstream:call_count")

    1000.times { RateCache.increment_quota_counter }

    assert RateCache.quota_exceeded?
  end
end