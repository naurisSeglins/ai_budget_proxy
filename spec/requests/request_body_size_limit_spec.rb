require "rails_helper"

RSpec.describe "Request body size limit", type: :request do
  let!(:proxy_token) { create(:proxy_token) }
  let(:headers) do
    {
      "Authorization" => "Bearer #{proxy_token.token}",
      "X-Provider-Authorization" => "Bearer sk-test",
      "Content-Type" => "application/json"
    }
  end

  it "rejects POST /proxy bodies larger than the configured limit with 413" do
    ClimateControl.modify(MAX_REQUEST_BODY_BYTES: "100") do
      post "/proxy", headers: headers, params: "x" * 500

      expect(response).to have_http_status(:payload_too_large)
      expect(response_json).to eq(errors: [ { status: 413, detail: "Request body too large" } ])
    end
  end

  it "allows bodies within the limit through to the controller" do
    body = { model: "gpt-4o-mini", messages: [ { role: "user", content: "hi" } ] }.to_json
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 200, body: { id: "c", model: "gpt-4o-mini", choices: [], usage: {} }.to_json)

    ClimateControl.modify(MAX_REQUEST_BODY_BYTES: "1000") do
      post "/proxy", headers: headers, params: body

      expect(response).to have_http_status(:ok)
    end
  end
end
