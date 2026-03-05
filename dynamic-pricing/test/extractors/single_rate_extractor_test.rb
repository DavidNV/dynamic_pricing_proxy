require "test_helper"

class SingleRateExtractorTest < ActiveSupport::TestCase
  RATES = [
    { "period" => "Summer", "hotel" => "FloatingPointResort", "room" => "SingletonRoom", "rate" => "15000" },
    { "period" => "Winter", "hotel" => "FloatingPointResort", "room" => "BooleanTwin",   "rate" => "28000" }
  ].freeze

  def build_extractor(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
    SingleRateExtractor.new(period:, hotel:, room:)
  end

  test "returns the matching rate from the rates array" do
    extractor = build_extractor
    result = extractor.call(RATES)

    assert_equal "Summer", result["period"]
    assert_equal "FloatingPointResort", result["hotel"]
    assert_equal "SingletonRoom", result["room"]
    assert_equal "15000", result["rate"]
  end

  test "returns nil when no matching rate is found" do
    extractor = build_extractor(period: "Autumn")
    result = extractor.call(RATES)

    assert_nil result
  end

  test "returns nil when rates array is empty" do
    extractor = build_extractor
    result = extractor.call([])

    assert_nil result
  end
end