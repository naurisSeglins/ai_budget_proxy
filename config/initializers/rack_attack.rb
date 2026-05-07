# Throttle abusive requests at the Rack layer.
#
# /proxy throttles (POST only):
#   - per-token (key = the proxy token in the Authorization header)
#   - per-IP    (secondary safety net for misbehaving clients)
#
# /tokens throttles:
#   - POST per-IP (registration spam prevention, hourly window)
#   - GET  per-IP (email enumeration / log-flood prevention, hourly window)
#
# Limits are read from ENV per request so they can be tuned in production
# without redeploying and stubbed in specs without touching the gem internals.

class Rack::Attack
  PROXY_PATH = "/proxy".freeze
  TOKENS_PATH = "/tokens".freeze

  # Tests run with Rails.cache = :null_store, which silently drops throttle
  # counters. Use a dedicated MemoryStore for rack-attack in test so throttles
  # actually count. In other envs Rails.cache (solid_cache_store in prod) is
  # the right choice and is what rack-attack uses by default.
  self.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?

  throttle("proxy/per_token",
    limit: ->(_req) { ENV.fetch("RATE_LIMIT_PER_TOKEN_RPM", "60").to_i },
    period: 60.seconds) do |req|
    if req.path == PROXY_PATH && req.post?
      raw = req.env["HTTP_AUTHORIZATION"]
      raw.sub(/\ABearer\s+/i, "").presence if raw.present?
    end
  end

  throttle("proxy/per_ip",
    limit: ->(_req) { ENV.fetch("RATE_LIMIT_PER_IP_RPM", "120").to_i },
    period: 60.seconds) do |req|
    req.ip if req.path == PROXY_PATH && req.post?
  end

  throttle("tokens/post_per_ip",
    limit: ->(_req) { ENV.fetch("RATE_LIMIT_TOKENS_PER_IP_HOUR", "10").to_i },
    period: 1.hour) do |req|
    req.ip if req.path == TOKENS_PATH && req.post?
  end

  throttle("tokens/get_per_ip",
    limit: ->(_req) { ENV.fetch("RATE_LIMIT_TOKENS_GET_PER_IP_HOUR", "60").to_i },
    period: 1.hour) do |req|
    req.ip if req.path == TOKENS_PATH && req.get?
  end

  # Project-standard error shape, plus a Retry-After header (seconds until the
  # current throttle window closes). Match data is set by rack-attack on the
  # request env when a throttle fires.
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    period = match_data[:period].to_i
    epoch_time = (req.env["rack.attack.epoch_time"] || Time.now.to_i).to_i
    retry_after = period.zero? ? 60 : (period - (epoch_time % period))

    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { errors: [ { status: 429, detail: "Rate limit exceeded" } ] }.to_json ]
    ]
  end
end
