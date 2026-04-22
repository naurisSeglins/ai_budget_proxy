class ProxyController < ApplicationController
  def create
    render json: OpenAiClient.new.chat_completion(proxy_params)
  rescue OpenAiClient::Error => e
    render(
      json: { errors: [{ status: 502, detail: e.message }] },
      status: :bad_gateway
    )
  end

  private

  def proxy_params
    params.except(:controller, :action, :proxy).permit!.to_h
  end
end