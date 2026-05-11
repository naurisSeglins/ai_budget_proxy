class TokensController < PublicController
  def create
    limit_millicents = dollars_to_millicents(params[:limit])

    unless limit_millicents
      return render json: {
        errors: [ { status: 422, detail: "Limit must be a positive number in dollars (e.g. 10 for $10)", source: { pointer: "/limit" } } ]
      }, status: :unprocessable_entity
    end

    proxy_token = ProxyToken.new(
      token: SecureRandom.hex(32),
      email: params[:email].presence,
      label: params[:label].presence,
      limit_millicents: limit_millicents
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

    tokens = ProxyToken.where(email: params[:email]).order(created_at: :desc).limit(100)

    render json: tokens.map { |t|
      {
        label: t.label,
        limit: millicents_to_dollars(t.limit_millicents),
        usage: millicents_to_dollars(t.usage_millicents),
        remaining: millicents_to_dollars(t.remaining_millicents),
        revoked: t.revoked,
        created_at: t.created_at
      }
    }
  end

  private

  def dollars_to_millicents(value)
    return nil if value.blank?
    millicents = (value.to_f * 100_000).round
    millicents > 0 ? millicents : nil
  end

  def millicents_to_dollars(millicents)
    (millicents / 100_000.0).round(2)
  end
end
