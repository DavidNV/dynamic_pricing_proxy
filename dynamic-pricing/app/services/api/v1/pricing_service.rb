module Api::V1
  class PricingService < BaseService
    def initialize(attributes:, result_extractor:)
      @attributes       = attributes
      @result_extractor = result_extractor
    end

    def run
      if RateCache.quota_exceeded?
        log_event("quota_exhausted", message: "Daily upstream quota reached")
        errors << "Pricing is temporarily unavailable. Please try again later."
        return
      end

      hits, misses = partition_by_cache
      log_event("cache_partition",
        total:  @attributes.length,
        hits:   hits.length,
        misses: misses.length
      )

      if misses.any?
        response = RateApiClient.get_rates(misses)
        process_response(response, misses)
      end

      @result = @result_extractor.call(fetch_all_cached_rates)
      errors << "Rate not found for the requested period, hotel and room" unless @result&.present?
    rescue RateApiClient::TimeoutError => e
      log_event("upstream_timeout", error: e.message)
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError => e
      log_event("upstream_connection_error", error: e.message)
      errors << "The upstream pricing service is unavailable, please try again later"
    end

    private

    def quota_exhausted!
      errors << "Pricing is temporarily unavailable. Please try again later."
    end

    def process_response(response, misses)
      parsed = parse_body(response.body)
      return unless parsed

      unless response.success?
        log_event("upstream_error", status: response.code, error: parsed['error'])
        errors << parsed['error']
        return
      end

      cache_rates(parsed['rates'])
      RateCache.increment_quota_counter

      log_event("upstream_success",
        requested: misses.length,
        returned:  Array(parsed['rates']).length,
        quota_used: RateCache.quota_count
      )
    end

    def cache_rates(rates)
      Array(rates).each do |rate|
        RateCache.write(period: rate['period'], hotel: rate['hotel'], room: rate['room'], rate:)
        log_event("cache_write",
          period: rate['period'],
          hotel:  rate['hotel'],
          room:   rate['room']
        )
      end
    end

    def partition_by_cache
      @attributes.partition do |attr|
        cached = RateCache.fetch(period: attr[:period], hotel: attr[:hotel], room: attr[:room])
        if cached
          log_event("cache_hit", period: attr[:period], hotel: attr[:hotel], room: attr[:room])
        else
          log_event("cache_miss", period: attr[:period], hotel: attr[:hotel], room: attr[:room])
        end
        cached
      end
    end

    def fetch_all_cached_rates
      @attributes.filter_map do |attr|
        RateCache.fetch(period: attr[:period], hotel: attr[:hotel], room: attr[:room])
      end
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      log_event("upstream_invalid_json", error: e.message)
      errors << "Received an invalid response from the upstream service"
      nil
    end

    def log_event(event, payload = {})
      Rails.logger.info({
        service:   "pricing_service",
        event:     event,
        timestamp: Time.now.utc.iso8601,
        **payload
      }.to_json)
    end
  end
end
