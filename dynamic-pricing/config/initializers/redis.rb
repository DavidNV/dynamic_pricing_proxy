REDIS = ConnectionPool::Wrapper.new(size: 5, timeout: 3) do
  Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
end