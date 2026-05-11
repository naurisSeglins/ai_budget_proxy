class CostCalculator
  # Milli-cents per 1,000,000 tokens (input, output).
  # 1 milli-cent = 1/1000 cent = 1/100_000 dollar.
  # Prices sourced from platform.openai.com/docs/pricing (2026-05-11).
  PRICING = {
    "gpt-4o"           => { input:   250_000, output: 1_000_000 },  # $2.50 / $10.00 per 1M
    "gpt-4o-mini"      => { input:    15_000, output:    60_000 },  # $0.15 / $0.60  per 1M
    "gpt-4-turbo"      => { input:   500_000, output: 1_500_000 },  # $5.00 / $15.00 per 1M
    "gpt-4"            => { input: 3_000_000, output: 6_000_000 },  # $30.00 / $60.00 per 1M
    "gpt-3.5-turbo"    => { input:    50_000, output:   100_000 },  # $0.50 / $1.00  per 1M
    "o1"               => { input: 1_500_000, output: 6_000_000 },  # $15.00 / $60.00 per 1M
    "o1-mini"          => { input:    55_000, output:   220_000 },  # $0.55 / $2.20  per 1M
    "o3"               => { input:   200_000, output:   800_000 },  # $2.00 / $8.00  per 1M
    "o3-mini"          => { input:   110_000, output:   440_000 }   # $1.10 / $4.40  per 1M
  }.freeze

  # Applied when the model is not in PRICING. Set at gpt-4 rates — the highest
  # known input rate — so the cap never silently disengages for unknown models.
  FALLBACK_RATE = { input: 3_000_000, output: 6_000_000 }.freeze  # $30.00 / $60.00 per 1M

  def initialize(response)
    @response = response
  end

  def millicents
    return 0 if prompt_tokens.nil? || completion_tokens.nil?

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

    match = PRICING.max_by { |key, _| model.start_with?(key) ? key.length : -1 }
    match = nil unless match && model.start_with?(match[0])
    if match
      @pricing = match[1]
    else
      Rails.logger.info("CostCalculator: no pricing for model #{model.inspect}, billed at fallback rate")
      @pricing = FALLBACK_RATE
    end
  end
end
