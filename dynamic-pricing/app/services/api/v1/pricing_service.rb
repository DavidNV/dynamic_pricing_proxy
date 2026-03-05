module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      response = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      process_response(response)
    rescue RateApiClient::TimeoutError
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError
      errors << "The upstream pricing service is unavailable, please try again later"
    end

    private

    def process_response(response)
      unless response.success?
        errors << JSON.parse(response.body)['error']
        return
      end

      parsed = parse_body(response.body)
      return unless parsed

      @result = find_rate(parsed)
      errors << "Rate not found for the requested period, hotel and room" unless @result
    end

    def parse_body(body)
      parsed = JSON.parse(body)
      unless parsed['rates'].is_a?(Array)
        errors << "unexpected response from upstream service"
        return nil
      end
      parsed
    rescue JSON::ParserError
      errors << "Received an invalid response from the upstream service"
      nil
    end

    def find_rate(parsed)
      parsed['rates'].detect do |rate|
        rate['period'] == @period &&
        rate['hotel'] == @hotel &&
        rate['room'] == @room
      end
    end
  end
end
