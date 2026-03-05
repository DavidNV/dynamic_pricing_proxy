require "test_helper"

class Api::V1::PricingControllerTest < ActionDispatch::IntegrationTest

  def successful_upstream_response(rate: "15000")
    body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "FloatingPointResort", "room" => "SingletonRoom", "rate" => rate }
      ]
    }.to_json
    OpenStruct.new(success?: true, body:)
  end

  setup do
    REDIS.del("upstream:call_count")
    REDIS.del("pricing:Summer:FloatingPointResort:SingletonRoom")
    REDIS.del("pricing:Winter:FloatingPointResort:BooleanTwin")
  end

  # GET /api/v1/pricing — single room
  test "returns full rate object for valid single room request" do
    RateApiClient.stub(:get_rates, successful_upstream_response) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel:  "FloatingPointResort",
        room:   "SingletonRoom"
      }

      assert_response :success
      assert_equal "application/json", @response.media_type

      json_response = JSON.parse(@response.body)
      assert_equal "Summer",             json_response["period"]
      assert_equal "FloatingPointResort", json_response["hotel"]
      assert_equal "SingletonRoom",       json_response["room"]
      assert_equal "15000",               json_response["rate"]
    end
  end

  test "returns 503 when quota is exhausted" do
    1000.times { RateCache.increment_quota_counter }

    get api_v1_pricing_url, params: {
      period: "Summer",
      hotel:  "FloatingPointResort",
      room:   "SingletonRoom"
    }

    assert_response :service_unavailable
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "temporarily unavailable"
  end

  test "returns 502 when upstream times out" do
    RateApiClient.stub(:get_rates, ->(*) { raise RateApiClient::TimeoutError, "timed out" }) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel:  "FloatingPointResort",
        room:   "SingletonRoom"
      }

      assert_response :bad_gateway
      json_response = JSON.parse(@response.body)
      assert_includes json_response["error"], "timed out"
    end
  end

  test "returns 502 when upstream connection is refused" do
    RateApiClient.stub(:get_rates, ->(*) { raise RateApiClient::ConnectionError, "unavailable" }) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel:  "FloatingPointResort",
        room:   "SingletonRoom"
      }

      assert_response :bad_gateway
      json_response = JSON.parse(@response.body)
      assert_includes json_response["error"], "unavailable"
    end
  end

  test "returns 404 when rate is not found" do
    body = { "rates" => [] }.to_json
    RateApiClient.stub(:get_rates, OpenStruct.new(success?: true, body:)) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel:  "FloatingPointResort",
        room:   "SingletonRoom"
      }

      assert_response :not_found
      json_response = JSON.parse(@response.body)
      assert_includes json_response["error"], "not found"
    end
  end

  test "returns 400 without any parameters" do
    get api_v1_pricing_url

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Missing required parameters"
  end

  test "returns 400 with empty parameters" do
    get api_v1_pricing_url, params: { period: "", hotel: "", room: "" }

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Missing required parameters"
  end

  test "returns 400 with invalid period" do
    get api_v1_pricing_url, params: {
      period: "summer-2024",
      hotel:  "FloatingPointResort",
      room:   "SingletonRoom"
    }

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Invalid period"
  end

  test "returns 400 with invalid hotel" do
    get api_v1_pricing_url, params: {
      period: "Summer",
      hotel:  "InvalidHotel",
      room:   "SingletonRoom"
    }

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Invalid hotel"
  end

  test "returns 400 with invalid room" do
    get api_v1_pricing_url, params: {
      period: "Summer",
      hotel:  "FloatingPointResort",
      room:   "InvalidRoom"
    }

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Invalid room"
  end

  # POST /api/v1/pricing — batch
  test "returns all rates for a valid batch request" do
    body = {
      "rates" => [
        { "period" => "Summer", "hotel" => "FloatingPointResort", "room" => "SingletonRoom", "rate" => "15000" },
        { "period" => "Winter", "hotel" => "FloatingPointResort", "room" => "BooleanTwin",   "rate" => "28000" }
      ]
    }.to_json
    RateApiClient.stub(:get_rates, OpenStruct.new(success?: true, body:)) do
      post api_v1_pricing_url, params: {
        attributes: [
          { period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom" },
          { period: "Winter", hotel: "FloatingPointResort", room: "BooleanTwin" }
        ]
      }, as: :json

      assert_response :success
      json_response = JSON.parse(@response.body)
      assert_equal 2,       json_response["rates"].length
      assert_equal "15000", json_response["rates"][0]["rate"]
      assert_equal "28000", json_response["rates"][1]["rate"]
    end
  end

  test "returns 400 for batch request without attributes" do
    post api_v1_pricing_url, params: {}, as: :json

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Missing required parameter: attributes"
  end

  test "returns 400 for batch request with invalid period" do
    post api_v1_pricing_url, params: {
      attributes: [
        { period: "InvalidPeriod", hotel: "FloatingPointResort", room: "SingletonRoom" }
      ]
    }, as: :json

    assert_response :bad_request
    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Invalid period"
  end
end
