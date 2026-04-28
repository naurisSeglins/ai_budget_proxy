class ProxyController < ApplicationController
  before_action :enforce_budget

  def create
    openai_response = OpenAiClient.new.chat_completion(proxy_params)
    record_usage(openai_response)
    render json: openai_response
  rescue OpenAiClient::Error => e
    render(
      json: { errors: [ { status: 502, detail: e.message } ] },
      status: :bad_gateway
    )
  end

  private

  def enforce_budget
    budget = Budget.first
    return if budget && !budget.exceeded?

    render(
      json: { errors: [ { status: 429, detail: "Budget exceeded" } ] },
      status: :too_many_requests
    )
  end

  def record_usage(openai_response)
    cost = CostCalculator.new(openai_response).cents
    return if cost.zero?

    Budget.first&.record_usage!(cost)
  rescue StandardError => e
    Rails.logger.error("Failed to record budget usage: #{e.class}: #{e.message}")
  end

  def proxy_params
    params.except(:controller, :action, :proxy).permit!.to_h
  end
end
