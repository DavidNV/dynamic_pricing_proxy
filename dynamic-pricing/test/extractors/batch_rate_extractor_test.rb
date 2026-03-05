require "test_helper"

class BatchRateExtractorTest < ActiveSupport::TestCase
  RATES = [
    { "period" => "Summer", "hotel" => "FloatingPointResort", "room" => "SingletonRoom", "rate" => "15000" },
    { "period" => "Winter", "hotel" => "FloatingPointResort", "room" => "BooleanTwin",   "rate" => "28000" }
  ].freeze

  def build_extractor
    BatchRateExtractor.new
  end

  test "returns all rates from the rates array" do
    extractor = build_extractor
    result = extractor.call(RATES)

    assert_equal 2, result.length
    assert_equal "Summer", result[0]["period"]
    assert_equal "Winter", result[1]["period"]
  end

  test "returns empty array when rates array is empty" do
    extractor = build_extractor
    result = extractor.call([])

    assert_empty result
  end
end