# Rejects requests whose declared Content-Length exceeds MAX_REQUEST_BODY_BYTES.
# Runs early in the Rack stack so abusive uploads are dropped before authentication,
# rate limiting, or any controller work.
class RequestBodySizeLimit
  DEFAULT_MAX_BYTES = 1_048_576 # 1 MiB

  def initialize(app)
    @app = app
  end

  def call(env)
    max_bytes = ENV.fetch("MAX_REQUEST_BODY_BYTES", DEFAULT_MAX_BYTES).to_i
    content_length = env["CONTENT_LENGTH"].to_i

    return too_large_response if content_length > max_bytes

    @app.call(env)
  end

  private

  def too_large_response
    [
      413,
      { "Content-Type" => "application/json" },
      [ { errors: [ { status: 413, detail: "Request body too large" } ] }.to_json ]
    ]
  end
end
