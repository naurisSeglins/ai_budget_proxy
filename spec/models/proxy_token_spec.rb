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

    it "is invalid without a limit_millicents" do
      expect(build(:proxy_token, limit_millicents: nil)).not_to be_valid
    end

    it "is invalid with limit_millicents of zero" do
      expect(build(:proxy_token, limit_millicents: 0)).not_to be_valid
    end

    it "is valid with a positive limit_millicents" do
      expect(build(:proxy_token, limit_millicents: 500)).to be_valid
    end
  end

  describe "#exceeded?" do
    it "returns false when usage is below the limit" do
      token = build(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 500_000)
      expect(token.exceeded?).to be false
    end

    it "returns true when usage equals the limit" do
      token = build(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 1_000_000)
      expect(token.exceeded?).to be true
    end

    it "returns true when usage exceeds the limit" do
      token = build(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 1_500_000)
      expect(token.exceeded?).to be true
    end
  end

  describe "#remaining_millicents" do
    it "returns the difference between limit and usage" do
      token = build(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 300_000)
      expect(token.remaining_millicents).to eq(700_000)
    end
  end

  describe "#record_usage!" do
    it "increments usage_millicents in the database" do
      token = create(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 0)
      token.record_usage!(50)
      expect(token.reload.usage_millicents).to eq(50)
    end

    it "syncs the in-memory value to the database (no stale +=)" do
      token = create(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 0)

      # Simulate a concurrent debit on a different process/thread.
      ProxyToken.where(id: token.id).update_all(usage_millicents: 100)

      token.record_usage!(50)

      # In-memory value must reflect what's actually in the DB (150),
      # not the stale-base `+=` arithmetic (50).
      expect(token.usage_millicents).to eq(150)
    end
  end
end
