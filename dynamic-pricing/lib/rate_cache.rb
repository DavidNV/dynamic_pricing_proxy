class RateCache
  TTL = 300 # 5 minutes in seconds
  QUOTA_KEY   = "upstream:call_count"
  QUOTA_LIMIT = 1000
  QUOTA_TTL   = 86400

  def self.fetch(period:, hotel:, room:)
    cached = REDIS.get(cache_key(period, hotel, room))
    JSON.parse(cached) if cached
  end

  def self.write(period:, hotel:, room:, rate:, ttl: TTL)
    REDIS.setex(cache_key(period, hotel, room), ttl, rate.to_json)
  end

  def self.increment_quota_counter
    # Increment the call count and set TTL if this is the first call of the day
    # https://redis.io/docs/latest/commands/incr/
    count = REDIS.incr(QUOTA_KEY)
    REDIS.expire(QUOTA_KEY, QUOTA_TTL) if count == 1
  end

  def self.quota_count
    REDIS.get(QUOTA_KEY).to_i
  end

  def self.quota_exceeded?
    quota_count >= QUOTA_LIMIT
  end

  private_class_method def self.cache_key(period, hotel, room)
    "pricing:#{period}:#{hotel}:#{room}"
  end
end