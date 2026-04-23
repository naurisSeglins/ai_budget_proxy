class Budget < ApplicationRecord
  validates :limit_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :usage_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def exceeded?
    usage_cents >= limit_cents
  end

  def remaining_cents
    limit_cents - usage_cents
  end

  def record_usage!(cents)
    self.class.update_counters(id, usage_cents: cents)
    self.usage_cents += cents
    self
  end
end
