class CostCalculator
  # Milli-cents per 1,000,000 tokens (input, output).
  # 1 milli-cent = 1/1000 cent = 1/100_000 dollar.
  # gpt-4o-mini: $0.15/1M input = 15_000 mc/1M, $0.60/1M output = 60_000 mc/1M.
  PRICING = {
    "gpt-4o-mini" => { input: 15_000, output: 60_000 }
  }.freeze

  def initialize(response)
    @response = response
  end

  def millicents
    return 0 if prompt_tokens.nil? || completion_tokens.nil?
    return 0 if pricing.nil?

    raw = prompt_tokens * pricing[:input] + completion_tokens * pricing[:output]
    (raw.to_f / 1_000_000).ceil
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
