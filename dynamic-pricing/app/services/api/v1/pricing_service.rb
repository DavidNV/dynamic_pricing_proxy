module Api::V1
  class PricingService < BaseService
    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      rate = RateApiClient.get_rate(period: @period, hotel: @hotel, room: @room)
      if rate.success?
        parsed_rate = parse_body(rate.body)
        return unless parsed_rate

        @result = find_rate(parsed_rate)
        errors << "Rate not found for the requested period, hotel and room" unless @result
      else
        errors << JSON.parse(rate.body)['error']
      end
    rescue RateApiClient::TimeoutError
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError
      errors << "The upstream pricing service is unavailable"
    end

    private

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
