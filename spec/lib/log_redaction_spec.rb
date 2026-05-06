require "rails_helper"

RSpec.describe LogRedaction do
  describe ".redact" do
    it "redacts the bearer value after Authorization" do
      input = "Authorization: Bearer abc123secret"

      expect(described_class.redact(input)).to eq("Authorization: Bearer [REDACTED]")
    end

    it "redacts the bearer value after X-Provider-Authorization" do
      input = "X-Provider-Authorization: Bearer sk-test-real-openai-key"

      expect(described_class.redact(input)).to eq("X-Provider-Authorization: Bearer [REDACTED]")
    end

    it "is case-insensitive on the header name" do
      input = "authorization: bearer abc123"

      expect(described_class.redact(input)).to eq("authorization: bearer [REDACTED]")
    end

    it "redacts both headers in the same line" do
      input = "headers={Authorization: Bearer aaa, X-Provider-Authorization: Bearer bbb}"

      result = described_class.redact(input)

      expect(result).to include("Authorization: Bearer [REDACTED]")
      expect(result).to include("X-Provider-Authorization: Bearer [REDACTED]")
      expect(result).not_to include("aaa")
      expect(result).not_to include("bbb")
    end

    it "leaves unrelated text unchanged" do
      input = "Started POST /proxy for 127.0.0.1 at 2026-05-06 10:00:00"

      expect(described_class.redact(input)).to eq(input)
    end

    it "returns a string when given a non-string argument" do
      expect(described_class.redact(nil)).to eq("")
      expect(described_class.redact(123)).to eq("123")
    end
  end
end
