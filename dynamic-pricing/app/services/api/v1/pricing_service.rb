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
        begin
          parsed_rate = JSON.parse(rate.body)
        rescue JSON::ParserError
          errors << "Received an invalid response from the upstream service"
          return
        end
        unless parsed_rate['rates'].is_a?(Array)
          errors << "unexpected response from upstream service"
          return
        end
        @result = parsed_rate['rates'].detect { |r| r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room }
        errors << "Rate not found for the requested period, hotel and room" unless @result
      else
        errors << JSON.parse(rate.body)['error']
      end
    rescue RateApiClient::TimeoutError
      errors << "The upstream pricing service timed out, please try again later"
    rescue RateApiClient::ConnectionError
      errors << "The upstream pricing service is unavailable"
    end
  end
end
