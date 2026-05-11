require "rails_helper"

RSpec.describe CostCalculator do
  describe "#millicents" do
    it "calculates cost for gpt-4o-mini" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      # $0.15/1M input + $0.60/1M output = 75¢ = 75_000 milli-cents
      expect(described_class.new(response).millicents).to eq(75_000)
    end

    it "calculates cost for gpt-4o" do
      response = {
        "model" => "gpt-4o",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      # $2.50/1M input + $10.00/1M output = $12.50 = 1_250_000 milli-cents
      expect(described_class.new(response).millicents).to eq(1_250_000)
    end

    it "calculates cost for o1" do
      response = {
        "model" => "o1",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      # $15.00/1M input + $60.00/1M output = $75 = 7_500_000 milli-cents
      expect(described_class.new(response).millicents).to eq(7_500_000)
    end

    it "calculates fractional milli-cents precisely for small requests" do
      response = {
        "model" => "gpt-4o-mini",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      # (1000*15_000 + 500*60_000) / 1_000_000 = 45 milli-cents
      expect(described_class.new(response).millicents).to eq(45)
    end

    it "matches versioned model names by prefix" do
      response = {
        "model" => "gpt-4o-mini-2024-07-18",
        "usage" => { "prompt_tokens" => 1_000_000, "completion_tokens" => 1_000_000 }
      }

      expect(described_class.new(response).millicents).to eq(75_000)
    end

    it "bills an unknown model at the fallback rate" do
      allow(Rails.logger).to receive(:info)
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(described_class.new(response).millicents).to be > 0
    end

    it "bills a blank model field at the fallback rate" do
      allow(Rails.logger).to receive(:info)
      response = {
        "model" => "",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(described_class.new(response).millicents).to be > 0
    end

    it "logs info when billing an unknown model at the fallback rate" do
      response = {
        "model" => "future-model-xyz",
        "usage" => { "prompt_tokens" => 1000, "completion_tokens" => 500 }
      }

      expect(Rails.logger).to receive(:info).with(/future-model-xyz.*fallback/i)

      described_class.new(response).millicents
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
  end
end
