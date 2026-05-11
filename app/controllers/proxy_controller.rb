class ProxyController < ApplicationController
  before_action :require_provider_credential
  before_action :enforce_budget
  before_action :parse_request_body

  def create
    openai_response = OpenAiClient.new(api_key: provider_api_key).chat_completion(@parsed_body)
    record_usage(openai_response)
    render json: openai_response
  rescue OpenAiClient::Error => e
    render(
      json: { errors: [ { status: 502, detail: e.message } ] },
      status: :bad_gateway
    )
  end

  private

  def require_provider_credential
    return if provider_api_key.present?

    render(
      json: { errors: [ { status: 401, detail: "Missing X-Provider-Authorization header" } ] },
      status: :unauthorized
    )
  end

  def enforce_budget
    # Row lock forces a fresh read and serializes the check across concurrent
    # requests for the same token, preventing stale-read races.
    exceeded = @current_token.with_lock { @current_token.exceeded? }

    return unless exceeded

    render(
      json: { errors: [ { status: 429, detail: "Budget exceeded" } ] },
      status: :too_many_requests
    )
  end

  def parse_request_body
    request.body.rewind
    @parsed_body = JSON.parse(request.body.read)
  rescue JSON::ParserError
    render(
      json: { errors: [ { status: 400, detail: "Request body is not valid JSON" } ] },
      status: :bad_request
    )
  end

  def provider_api_key
    @provider_api_key ||= extract_provider_api_key
  end

  def extract_provider_api_key
    raw = request.headers["X-Provider-Authorization"]
    return nil if raw.blank?

    raw.sub(/\ABearer\s+/i, "")
  end

  def record_usage(openai_response)
    cost = CostCalculator.new(openai_response).millicents
    return if cost.zero?

    @current_token.record_usage!(cost)
  rescue StandardError => e
    Rails.logger.error("Failed to record budget usage: #{e.class}")
  end
end
