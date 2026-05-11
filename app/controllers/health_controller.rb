class HealthController < PublicController
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    head :ok
  rescue StandardError => e
    Rails.logger.error("Healthcheck failed: #{e.class}")
    head :service_unavailable
  end
end
