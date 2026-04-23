require "rails_helper"

RSpec.describe CostCalculator do
  describe "#cents" do
    it "calculates cost from prompt and completion tokens for gpt-4o-mini" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      # gpt-4o-mini: $0.15/1M input + $0.60/1M output = 15¢ + 60¢ = 75¢
      expect(described_class.new(response).cents).to eq(75)
    end

    it "rounds fractional cents up" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      # (1000*15 + 500*60) / 1_000_000 = 0.045 → ceil = 1
      expect(described_class.new(response).cents).to eq(1)
    end

    it "matches versioned model names by prefix" do
      response = {
        "model" => "gpt-4o-mini-2024-07-18",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      expect(described_class.new(response).cents).to eq(75)
    end

    it "returns 0 when usage is missing" do
      response = { "model" => "gpt-4o-mini" }

      expect(described_class.new(response).cents).to eq(0)
    end

    it "returns 0 when prompt_tokens is missing" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "completion_tokens" => 500 }
      }

      expect(described_class.new(response).cents).to eq(0)
    end

    it "returns 0 for an unknown model" do
      allow(Rails.logger).to receive(:warn)
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(described_class.new(response).cents).to eq(0)
    end

    it "logs a warning for an unknown model" do
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(Rails.logger).to receive(:warn).with(/future-model-xyz/)

      described_class.new(response).cents
    end
  end
end
