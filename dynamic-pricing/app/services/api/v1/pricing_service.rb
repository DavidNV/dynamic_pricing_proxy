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
      parsed = parse_body(response.body)
      return unless parsed

      unless response.success?
        errors << parsed['error']
        return
      end

      @result = find_rate(parsed)
      errors << "Rate not found for the requested period, hotel and room" unless @result
    end

    def find_rate(parsed)
      Array(parsed['rates']).detect do |rate|
        rate['period'] == @period &&
        rate['hotel']  == @hotel  &&
        rate['room']   == @room
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
