require "rails_helper"

RSpec.describe "Rate limiting on POST /proxy", type: :request do
  let!(:proxy_token) { create(:proxy_token) }
  let(:headers) do
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{proxy_token.token}",
      "X-Provider-Authorization" => "Bearer sk-test-provider-key"
    }
  end
  let(:openai_endpoint) { "https://api.openai.com/v1/chat/completions" }
  let(:body) { { model: "gpt-4o-mini", messages: [ { role: "user", content: "hi" } ] } }
  let(:openai_response) do
    {
      id: "chatcmpl-1",
      model: "gpt-4o-mini-2024-07-18",
      choices: [ { message: { role: "assistant", content: "ok" } } ],
      usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 }
    }
  end

  before do
    Rack::Attack.cache.store.clear
    stub_request(:post, openai_endpoint).to_return(
      status: 200,
      body: openai_response.to_json,
      headers: { "Content-Type" => "application/json" }
    )
  end

  describe "per-token throttle" do
    around do |example|
      ClimateControl.modify(RATE_LIMIT_PER_TOKEN_RPM: "3", RATE_LIMIT_PER_IP_RPM: "1000") { example.run }
    end

    it "allows requests within the limit" do
      3.times do
        post "/proxy", params: body, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    it "returns 429 with Retry-After when the token exceeds the limit" do
      3.times { post "/proxy", params: body, headers: headers, as: :json }

      post "/proxy", params: body, headers: headers, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response_json).to eq(errors: [ { status: 429, detail: "Rate limit exceeded" } ])
      expect(response.headers["Retry-After"]).to be_present
      expect(response.headers["Retry-After"].to_i).to be > 0
    end

    it "does not forward the throttled request to OpenAI" do
      3.times { post "/proxy", params: body, headers: headers, as: :json }
      WebMock.reset_executed_requests!

      post "/proxy", params: body, headers: headers, as: :json

      expect(WebMock).not_to have_requested(:post, openai_endpoint)
    end

    it "throttles per-token, not globally — a different token is unaffected" do
      3.times { post "/proxy", params: body, headers: headers, as: :json }

      other_token = create(:proxy_token)
      other_headers = headers.merge("Authorization" => "Bearer #{other_token.token}")

      post "/proxy", params: body, headers: other_headers, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "per-IP throttle" do
    around do |example|
      ClimateControl.modify(RATE_LIMIT_PER_TOKEN_RPM: "1000", RATE_LIMIT_PER_IP_RPM: "3") { example.run }
    end

    it "throttles by IP across different tokens from the same caller" do
      tokens = Array.new(4) { create(:proxy_token) }

      tokens.first(3).each do |t|
        h = headers.merge("Authorization" => "Bearer #{t.token}")
        post "/proxy", params: body, headers: h, as: :json
        expect(response).to have_http_status(:ok)
      end

      h = headers.merge("Authorization" => "Bearer #{tokens.last.token}")
      post "/proxy", params: body, headers: h, as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end
  end
end
