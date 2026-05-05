class OpenAiClient
  Error = Class.new(StandardError)
  MissingApiKeyError = Class.new(Error)

  ENDPOINT = "https://api.openai.com/v1/chat/completions".freeze
  TIMEOUT_SECONDS = 30

  def initialize(api_key:)
    raise MissingApiKeyError, "OpenAI API key is not configured" if api_key.blank?

    @api_key = api_key
  end

  def chat_completion(payload)
    response = connection.post(ENDPOINT, payload.to_json, request_headers)
    raise Error, "OpenAI returned #{response.status}: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  private

  def connection
    @connection ||= Faraday.new(request: { timeout: TIMEOUT_SECONDS })
  end

  def request_headers
    {
      "Authorization" => "Bearer #{@api_key}",
      "Content-Type" => "application/json"
    }
  end
end
