class OpenAiClient
  Error = Class.new(StandardError)
  MissingApiKeyError = Class.new(Error)

  ENDPOINT = "https://api.openai.com/v1/chat/completions".freeze
  OPEN_TIMEOUT_SECONDS = 5   # TCP + SSL handshake; fail fast if OpenAI is unreachable
  READ_TIMEOUT_SECONDS = 30  # response body; gpt-4o-mini typically responds in 1-3s

  # Shared, thread-safe persistent connection. Reuses TCP/TLS across requests
  # so we don't pay the handshake cost on every call. Per-request headers
  # (including the caller's Authorization) are passed to .post, not configured
  # on the connection — the connection itself is credential-agnostic.
  CONNECTION = Faraday.new(
    request: { open_timeout: OPEN_TIMEOUT_SECONDS, timeout: READ_TIMEOUT_SECONDS }
  ) do |conn|
    conn.adapter :net_http_persistent
  end

  def initialize(api_key:)
    raise MissingApiKeyError, "OpenAI API key is not configured" if api_key.blank?

    @api_key = api_key
  end

  def chat_completion(payload)
    response = CONNECTION.post(ENDPOINT, payload.to_json, request_headers)
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

  def request_headers
    {
      "Authorization" => "Bearer #{@api_key}",
      "Content-Type" => "application/json"
    }
  end
end
