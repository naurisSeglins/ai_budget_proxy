class ApplicationController < ActionController::API
  prepend_before_action :authenticate_proxy_caller

  private

  def authenticate_proxy_caller
    token = extract_proxy_token
    @current_token = ProxyToken.find_by(token: token, revoked: false) if token
    return if @current_token

    render(
      json: { errors: [ { status: 401, detail: "Unauthorized" } ] },
      status: :unauthorized
    )
  end

  def extract_proxy_token
    raw = request.headers["Authorization"]
    return nil if raw.blank?

    raw.sub(/\ABearer\s+/i, "")
  end
end
