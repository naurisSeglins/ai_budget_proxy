class ProxyController < ApplicationController
  def create
    render json: {
      status: "ok",
      message: "proxy is running",
      request: proxy_params
    }
  end

  private

  def proxy_params
    params.except(:controller, :action, :proxy).permit!.to_h
  end
end
