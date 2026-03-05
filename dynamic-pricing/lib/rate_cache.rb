class RateCache
  TTL = 300 # 5 minutes in seconds

  def self.fetch(period:, hotel:, room:)
    cached = REDIS.get(cache_key(period, hotel, room))
    JSON.parse(cached) if cached
  end

  def self.write(period:, hotel:, room:, rate:)
    REDIS.setex(cache_key(period, hotel, room), TTL, rate.to_json)
  end

  private_class_method def self.cache_key(period, hotel, room)
    "pricing:#{period}:#{hotel}:#{room}"
  end
end