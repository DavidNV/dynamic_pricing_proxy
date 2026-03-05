class RateApiClient
  include HTTParty
  base_uri ENV.fetch('RATE_API_URL', 'http://localhost:8080')
  headers "Content-Type" => "application/json"
  headers 'token' => ENV.fetch('RATE_API_TOKEN', '04aa6f42aa03f220c2ae9a276cd68c62')

  class RateApiError < StandardError; end
  class TimeoutError < RateApiError; end
  class ConnectionError < RateApiError; end

  def self.get_rates(attributes)
    body = { attributes: Array(attributes) }.to_json
    self.post("/pricing", body:)
  rescue Net::ReadTimeout, Net::OpenTimeout
    raise TimeoutError, "The upstream pricing service timed out"
  rescue Errno::ECONNREFUSED, SocketError
    raise ConnectionError, "The upstream pricing service is unavailable"
  end
end
