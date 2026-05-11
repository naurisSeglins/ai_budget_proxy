class ProxyToken < ApplicationRecord
  validates :token, presence: true, uniqueness: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :limit_millicents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :usage_millicents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def exceeded?
    usage_millicents >= limit_millicents
  end

  def remaining_millicents
    limit_millicents - usage_millicents
  end

  def record_usage!(millicents)
    self.class.update_counters(id, usage_millicents: millicents)
    reload
  end
end
