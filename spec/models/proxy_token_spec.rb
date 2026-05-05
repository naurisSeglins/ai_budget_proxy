require "rails_helper"

RSpec.describe ProxyToken, type: :model do
  describe "validations" do
    subject { build(:proxy_token) }

    it { is_expected.to validate_presence_of(:token) }
    it { is_expected.to validate_uniqueness_of(:token) }
    it { is_expected.to validate_presence_of(:email) }

    it "is invalid with a malformed email" do
      expect(build(:proxy_token, email: "not-an-email")).not_to be_valid
    end

    it "is valid with a well-formed email" do
      expect(build(:proxy_token, email: "user@example.com")).to be_valid
    end

    it "is invalid without a limit_cents" do
      expect(build(:proxy_token, limit_cents: nil)).not_to be_valid
    end

    it "is invalid with limit_cents of zero" do
      expect(build(:proxy_token, limit_cents: 0)).not_to be_valid
    end

    it "is valid with a positive limit_cents" do
      expect(build(:proxy_token, limit_cents: 500)).to be_valid
    end
  end

  describe "#exceeded?" do
    it "returns false when usage is below the limit" do
      token = build(:proxy_token, limit_cents: 1000, usage_cents: 500)
      expect(token.exceeded?).to be false
    end

    it "returns true when usage equals the limit" do
      token = build(:proxy_token, limit_cents: 1000, usage_cents: 1000)
      expect(token.exceeded?).to be true
    end

    it "returns true when usage exceeds the limit" do
      token = build(:proxy_token, limit_cents: 1000, usage_cents: 1500)
      expect(token.exceeded?).to be true
    end
  end

  describe "#remaining_cents" do
    it "returns the difference between limit and usage" do
      token = build(:proxy_token, limit_cents: 1000, usage_cents: 300)
      expect(token.remaining_cents).to eq(700)
    end
  end

  describe "#record_usage!" do
    it "increments usage_cents in the database" do
      token = create(:proxy_token, limit_cents: 1000, usage_cents: 0)
      token.record_usage!(50)
      expect(token.reload.usage_cents).to eq(50)
    end
  end
end
