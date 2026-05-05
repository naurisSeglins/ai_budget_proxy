class TokensController < PublicController
  def create
    limit_cents = dollars_to_cents(params[:limit])

    unless limit_cents
      return render json: {
        errors: [ { status: 422, detail: "Limit must be a positive number in dollars (e.g. 10 for $10)", source: { pointer: "/limit" } } ]
      }, status: :unprocessable_entity
    end

    proxy_token = ProxyToken.new(
      token: SecureRandom.hex(32),
      email: params[:email].presence,
      label: params[:label].presence,
      limit_cents: limit_cents
    )

    if proxy_token.save
      render json: { token: proxy_token.token }, status: :created
    else
      render json: {
        errors: proxy_token.errors.map { |e|
          { status: 422, detail: e.full_message, source: { pointer: "/#{e.attribute}" } }
        }
      }, status: :unprocessable_entity
    end
  end

  def index
    return render json: {
      errors: [ { status: 422, detail: "Email can't be blank", source: { pointer: "/email" } } ]
    }, status: :unprocessable_entity unless params[:email].present?

    tokens = ProxyToken.where(email: params[:email]).order(created_at: :desc)

    render json: tokens.map { |t|
      {
        label: t.label,
        limit: cents_to_dollars(t.limit_cents),
        usage: cents_to_dollars(t.usage_cents),
        remaining: cents_to_dollars(t.remaining_cents),
        revoked: t.revoked,
        created_at: t.created_at
      }
    }
  end

  private

  def dollars_to_cents(value)
    return nil if value.blank?
    cents = (value.to_f * 100).round
    cents > 0 ? cents : nil
  end

  def cents_to_dollars(cents)
    (cents / 100.0).round(2)
  end
end
