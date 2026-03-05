module Api::V1
  class PricingService < BaseService
    def initialize(attributes:, result_extractor:)
      @attributes       = attributes
      @result_extractor = result_extractor
    end

    def run
      return quota_exhausted! if RateCache.quota_exceeded?

      _hits, misses = partition_by_cache

      if misses.any?
        response = RateApiClient.get_rates(misses)
        process_response(response)
      end

      @result = @result_extractor.call(fetch_all_cached_rates)
      errors << "Rate not found for the requested period, hotel and room" unless @result&.present?
    rescue RateApiClient::TimeoutError
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError
      errors << "The upstream pricing service is unavailable, please try again later"
    end

    private

    def quota_exhausted!
      errors << "Pricing is temporarily unavailable. Please try again later."
    end

    def process_response(response)
      parsed = parse_body(response.body)
      return unless parsed

      unless response.success?
        errors << parsed['error']
        return
      end

      cache_rates(parsed['rates'])
      RateCache.increment_quota_counter
    end

    def cache_rates(rates)
      Array(rates).each do |rate|
        RateCache.write(period: rate['period'], hotel: rate['hotel'], room: rate['room'], rate:)
      end
    end

    def partition_by_cache
      @attributes.partition do |attr|
        RateCache.fetch(period: attr[:period], hotel: attr[:hotel], room: attr[:room])
      end
    end

    def fetch_all_cached_rates
      @attributes.filter_map do |attr|
        RateCache.fetch(period: attr[:period], hotel: attr[:hotel], room: attr[:room])
      end
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      errors << "Received an invalid response from the upstream service"
      nil
    end
  end
end
