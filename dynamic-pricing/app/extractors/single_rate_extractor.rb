class SingleRateExtractor
  def initialize(period:, hotel:, room:)
    @period = period
    @hotel  = hotel
    @room   = room
  end

  def call(rates)
    rates.detect { |r| r['period'] == @period && r['hotel'] == @hotel && r['room'] == @room }
  end
end