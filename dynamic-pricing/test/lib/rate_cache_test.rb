require "test_helper"

class RateCacheTest < ActiveSupport::TestCase
  VALID_PERIOD = "Summer"
  VALID_HOTEL  = "FloatingPointResort"
  VALID_ROOM   = "SingletonRoom"
  VALID_RATE   = { "period" => VALID_PERIOD, "hotel" => VALID_HOTEL, "room" => VALID_ROOM, "rate" => "15000" }.freeze

  def cache_key
    "pricing:#{VALID_PERIOD}:#{VALID_HOTEL}:#{VALID_ROOM}"
  end

  setup do
    REDIS.del(cache_key)
  end

  test "returns nil on a cache miss" do
    result = RateCache.fetch(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)
    assert_nil result
  end
end