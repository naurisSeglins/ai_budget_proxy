require "rails_helper"

RSpec.describe CostCalculator do
  describe "#millicents" do
    it "calculates cost in milli-cents from prompt and completion tokens for gpt-4o-mini" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      # gpt-4o-mini: $0.15/1M input + $0.60/1M output = 15¢ + 60¢ = 75¢ = 75_000 milli-cents
      expect(described_class.new(response).millicents).to eq(75_000)
    end

    it "calculates fractional milli-cents precisely for small requests" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      # (1000*15_000 + 500*60_000) / 1_000_000 = 45_000_000 / 1_000_000 = 45 milli-cents
      expect(described_class.new(response).millicents).to eq(45)
    end

    it "matches versioned model names by prefix" do
      response = {
        "model" => "gpt-4o-mini-2024-07-18",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      expect(described_class.new(response).millicents).to eq(75_000)
    end

    it "returns 0 when usage is missing" do
      response = { "model" => "gpt-4o-mini" }

      expect(described_class.new(response).millicents).to eq(0)
    end

    it "returns 0 when prompt_tokens is missing" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "completion_tokens" => 500 }
      }

      expect(described_class.new(response).millicents).to eq(0)
    end

    it "returns 0 for an unknown model" do
      allow(Rails.logger).to receive(:warn)
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(described_class.new(response).millicents).to eq(0)
    end

    it "logs a warning for an unknown model" do
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(Rails.logger).to receive(:warn).with(/future-model-xyz/)

      described_class.new(response).millicents
    end
  end
end
