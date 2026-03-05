require "test_helper"

class Api::V1::PricingServiceTest < ActiveSupport::TestCase
  VALID_PERIOD = "Summer"
  VALID_HOTEL  = "FloatingPointResort"
  VALID_ROOM   = "SingletonRoom"

  setup do
    REDIS.del("upstream:call_count")
  end

  def build_service
    extractor = SingleRateExtractor.new(period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM)
    Api::V1::PricingService.new(
      attributes: [{ period: VALID_PERIOD, hotel: VALID_HOTEL, room: VALID_ROOM }],
      result_extractor: extractor
    )
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
    RateApiClient.stub(:get_rates, successful_upstream_response) do
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

  test "returns all rates for a batch request" do
    body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "FloatingPointResort", "room" => "SingletonRoom", "rate" => "15000" },
        { "period" => "Winter", "hotel" => "FloatingPointResort", "room" => "BooleanTwin",   "rate" => "28000" }
      ]
    }.to_json
    batch_response = OpenStruct.new(success?: true, body:)

    attributes = [
      { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" },
      { period: "Winter", hotel: "FloatingPointResort", room: "BooleanTwin" }
    ]

    RateApiClient.stub(:get_rates, batch_response) do
      service = Api::V1::PricingService.new(
        attributes: attributes,
        result_extractor: BatchRateExtractor.new
      )
      service.run

      assert service.valid?
      assert_empty service.errors
      assert_equal 2,        service.result.length
      assert_equal "15000",  service.result[0]["rate"]
      assert_equal "28000",  service.result[1]["rate"]
    end
  end

  test "is invalid when upstream returns a failure response" do
    body = { "error" => "Some failure occurred" }.to_json
    failed_response = OpenStruct.new(success?: false, body:)

    RateApiClient.stub(:get_rates, failed_response) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "Some failure occurred"
    end
  end

  test "is invalid when upstream returns success but rate is missing from response" do
    body = { "rates" => [] }.to_json
    empty_response = OpenStruct.new(success?: true, body:)

    RateApiClient.stub(:get_rates, empty_response) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "Rate not found"
    end
  end

  test "is invalid when upstream returns success but rates key is missing" do
    body = {}.to_json
    bad_response = OpenStruct.new(success?: true, body:)

    RateApiClient.stub(:get_rates, bad_response) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "Rate not found"
    end
  end

  test "is invalid when upstream returns malformed JSON" do
    malformed_response = OpenStruct.new(success?: true, body: "something_awful_happened{{")

    RateApiClient.stub(:get_rates, malformed_response) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "invalid response"
    end
  end

  test "is invalid when upstream times out" do
    timeout_error =
      RateApiClient::TimeoutError.new("The upstream pricing service timed out")

    RateApiClient.stub(:get_rates, ->(*) { raise timeout_error }) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "timed out"
    end
  end

  test "is invalid when upstream connection is refused" do
    connection_refused_error =
      RateApiClient::ConnectionError.new("The upstream pricing service is unavailable")

    RateApiClient.stub(:get_rates, ->(*) { raise connection_refused_error }) do
      service = build_service
      service.run

      refute service.valid?
      assert_includes service.errors.join, "unavailable"
    end
  end

  test "is invalid when daily quota is exhausted" do
    1000.times { RateCache.increment_quota_counter }
    service = build_service
    service.run

    refute service.valid?
    assert_includes service.errors.join, "Pricing is temporarily unavailable"
  end
end