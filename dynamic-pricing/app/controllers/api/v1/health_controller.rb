# app/controllers/api/v1/health_controller.rb
class Api::V1::HealthController < ApplicationController
  def show
    quota_count = RateCache.quota_count
    quota_limit = RateCache::QUOTA_LIMIT

    render json: {
      status:  "ok",
      redis:   redis_status,
      quota:   {
        used:      quota_count,
        limit:     quota_limit,
        remaining: quota_limit - quota_count,
        healthy:   quota_count < quota_limit
      },
      version: Rails.version,
      env:     Rails.env
    }
  end

  private

  def redis_status
    REDIS.ping == "PONG" ? "ok" : "degraded"
  rescue => e
    "unavailable"
  end
end