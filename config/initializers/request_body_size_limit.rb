require "request_body_size_limit"

# Insert at position 0 so the size check runs before any other middleware,
# including Rack::Attack — we don't want a 100MB body to consume memory or
# bandwidth just to hit a rate-limit check.
Rails.application.config.middleware.insert 0, RequestBodySizeLimit
