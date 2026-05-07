require "rails_helper"

RSpec.describe "Rate limiting on /tokens", type: :request do
  describe "POST /tokens per-IP throttle" do
    let(:params) { { email: "alice@example.com", limit: 10 } }

    around do |example|
      ClimateControl.modify(RATE_LIMIT_TOKENS_PER_IP_HOUR: "3") { example.run }
    end

    it "allows requests within the limit" do
      3.times do
        post "/tokens", params: params, as: :json
        expect(response).to have_http_status(:created)
      end
    end

    it "returns 429 with Retry-After when the limit is exceeded" do
      3.times { post "/tokens", params: params, as: :json }

      post "/tokens", params: params, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response_json).to eq(errors: [ { status: 429, detail: "Rate limit exceeded" } ])
      expect(response.headers["Retry-After"]).to be_present
      expect(response.headers["Retry-After"].to_i).to be > 0
    end

    it "does not throttle a different IP" do
      3.times { post "/tokens", params: params, as: :json }

      post "/tokens", params: { email: "bob@example.com", limit: 5 }, as: :json,
           headers: { "REMOTE_ADDR" => "1.2.3.4" }

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /tokens per-IP throttle" do
    let!(:proxy_token) { create(:proxy_token, email: "alice@example.com") }

    around do |example|
      ClimateControl.modify(RATE_LIMIT_TOKENS_GET_PER_IP_HOUR: "3") { example.run }
    end

    it "allows requests within the limit" do
      3.times do
        get "/tokens", params: { email: "alice@example.com" }
        expect(response).to have_http_status(:ok)
      end
    end

    it "returns 429 with Retry-After when the limit is exceeded" do
      3.times { get "/tokens", params: { email: "alice@example.com" } }

      get "/tokens", params: { email: "alice@example.com" }

      expect(response).to have_http_status(:too_many_requests)
      expect(response_json).to eq(errors: [ { status: 429, detail: "Rate limit exceeded" } ])
      expect(response.headers["Retry-After"]).to be_present
      expect(response.headers["Retry-After"].to_i).to be > 0
    end

    it "does not throttle a different IP" do
      3.times { get "/tokens", params: { email: "alice@example.com" } }

      get "/tokens", params: { email: "alice@example.com" },
          headers: { "REMOTE_ADDR" => "1.2.3.4" }

      expect(response).to have_http_status(:ok)
    end

    it "POST and GET throttles are independent — exhausting GET does not affect POST" do
      3.times { get "/tokens", params: { email: "alice@example.com" } }

      post "/tokens", params: { email: "new@example.com", limit: 5 }, as: :json

      expect(response).to have_http_status(:created)
    end
  end
end
