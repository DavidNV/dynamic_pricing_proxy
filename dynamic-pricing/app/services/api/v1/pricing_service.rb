module Api::V1
  class PricingService < BaseService
    def initialize(attributes:, result_extractor:)
      @attributes       = attributes
      @result_extractor = result_extractor
    end

    def run
      response = RateApiClient.get_rates(@attributes)
      process_response(response)
    rescue RateApiClient::TimeoutError
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError
      errors << "The upstream pricing service is unavailable, please try again later"
    end

    private

    def process_response(response)
      parsed = parse_body(response.body)
      return unless parsed

      unless response.success?
        errors << parsed['error']
        return
      end

      @result = @result_extractor.call(Array(parsed['rates']))
      errors << "Rate not found for the requested period, hotel and room" unless @result&.present?
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      errors << "Received an invalid response from the upstream service"
      nil
    end
  end
end
