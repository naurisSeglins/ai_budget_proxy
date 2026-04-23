require "rails_helper"

RSpec.describe Budget, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:limit_cents) }
    it { is_expected.to validate_numericality_of(:limit_cents).only_integer.is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:usage_cents).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "#exceeded?" do
    it "is true when usage_cents equals limit_cents" do
      budget = build_stubbed(:budget, limit_cents: 1000, usage_cents: 1000)
      expect(budget.exceeded?).to be true
    end

    it "is true when usage_cents is greater than limit_cents" do
      budget = build_stubbed(:budget, limit_cents: 1000, usage_cents: 1500)
      expect(budget.exceeded?).to be true
    end

    it "is false when usage_cents is less than limit_cents" do
      budget = build_stubbed(:budget, limit_cents: 1000, usage_cents: 999)
      expect(budget.exceeded?).to be false
    end
  end

  describe "#remaining_cents" do
    it "returns limit_cents minus usage_cents" do
      budget = build_stubbed(:budget, limit_cents: 1000, usage_cents: 300)
      expect(budget.remaining_cents).to eq(700)
    end

    it "returns 0 when usage_cents equals limit_cents" do
      budget = build_stubbed(:budget, limit_cents: 1000, usage_cents: 1000)
      expect(budget.remaining_cents).to eq(0)
    end
  end

  describe "#record_usage!" do
    it "persists an incremented usage_cents" do
      budget = create(:budget, limit_cents: 1000, usage_cents: 100)

      budget.record_usage!(50)

      expect(budget.reload.usage_cents).to eq(150)
    end

    it "updates usage_cents on the receiver in memory" do
      budget = create(:budget, limit_cents: 1000, usage_cents: 100)

      budget.record_usage!(50)

      expect(budget.usage_cents).to eq(150)
    end
  end
end
