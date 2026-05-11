class OpenAiClient
  Error = Class.new(StandardError)
  MissingApiKeyError = Class.new(Error)

  ENDPOINT = "https://api.openai.com/v1/chat/completions".freeze
  OPEN_TIMEOUT_SECONDS = 5   # TCP + SSL handshake; fail fast if OpenAI is unreachable
  READ_TIMEOUT_SECONDS = 30  # response body; gpt-4o-mini typically responds in 1-3s

  def initialize(api_key:)
    raise MissingApiKeyError, "OpenAI API key is not configured" if api_key.blank?

    @api_key = api_key
  end

  def chat_completion(payload)
    response = connection.post(ENDPOINT, payload.to_json, request_headers)
    unless response.success?
      Rails.logger.error("OpenAI returned #{response.status}")
      raise Error, "OpenAI returned #{response.status}"
    end

    JSON.parse(response.body)
  rescue Faraday::Error => e
    Rails.logger.error("OpenAI network error: #{e.class}")
    raise Error, "OpenAI request failed: #{e.class}"
  end

  private

  def connection
    @connection ||= Faraday.new(request: { open_timeout: OPEN_TIMEOUT_SECONDS, timeout: READ_TIMEOUT_SECONDS })
  end

  def request_headers
    {
      "Authorization" => "Bearer #{@api_key}",
      "Content-Type" => "application/json"
    }
  end
end
