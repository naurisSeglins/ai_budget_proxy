class CostCalculator
  # Cents per 1,000,000 tokens (input, output)
  PRICING = {
    "gpt-4o-mini" => { input: 15, output: 60 }
  }.freeze

  def initialize(response)
    @response = response
  end

  def cents
    return 0 if prompt_tokens.nil? || completion_tokens.nil?
    return 0 if pricing.nil?

    micro_cents = prompt_tokens * pricing[:input] + completion_tokens * pricing[:output]
    (micro_cents.to_f / 1_000_000).ceil
  end

  private

  def prompt_tokens
    @response.dig("usage", "prompt_tokens")
  end

  def completion_tokens
    @response.dig("usage", "completion_tokens")
  end

  def model
    @response["model"].to_s
  end

  def pricing
    return @pricing if defined?(@pricing)

    match = PRICING.find { |key, _| model.start_with?(key) }
    if match
      @pricing = match[1]
    else
      Rails.logger.warn("CostCalculator: no pricing for model #{model.inspect}")
      @pricing = nil
    end
  end
end
