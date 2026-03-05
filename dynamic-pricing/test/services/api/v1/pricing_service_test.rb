require "test_helper"

class Api::V1::PricingServiceTest < ActiveSupport::TestCase
  VALID_PERIOD = "Summer"
  VALID_HOTEL  = "FloatingPointResort"
  VALID_ROOM   = "SingletonRoom"

  def build_service(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)
    Api::V1::PricingService.new(period:, hotel:, room:)
  end

  def successful_upstream_response(rate: "15000")
    body = {
      "rates" => [
        {
          "period" => VALID_PERIOD,
          "hotel"  => VALID_HOTEL,
          "room"   => VALID_ROOM,
          "rate"   => rate
        }
      ]
    }.to_json
    OpenStruct.new(success?: true, body:)
  end

  test "returns full rate object on success" do
    RateApiClient.stub(:get_rate, successful_upstream_response) do
      service = build_service
      service.run

      assert service.valid?
      assert_empty service.errors

      assert_equal VALID_PERIOD, service.result["period"]
      assert_equal VALID_HOTEL,  service.result["hotel"]
      assert_equal VALID_ROOM,   service.result["room"]
      assert_equal "15000",      service.result["rate"]
    end
  end

end