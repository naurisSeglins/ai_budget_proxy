require "rails_helper"

RSpec.describe ProxyController, type: :request do
  describe "POST #create /proxy" do
    subject(:make_request) { post "/proxy", headers: headers, params: params, as: :json }

    let!(:proxy_token) { create(:proxy_token) }
    let(:provider_api_key) { "Bearer sk-test-provider-key" }
    let(:headers) do
      {
        "Accept" => "application/json",
        "Authorization" => "Bearer #{proxy_token.token}",
        "X-Provider-Authorization" => provider_api_key
      }
    end
    let(:params) do
      {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a code review assistant." },
          { role: "user", content: "Review this Ruby method for performance issues." }
        ],
        temperature: 0.7,
        max_tokens: 500
      }
    end
    let(:openai_endpoint) { "https://api.openai.com/v1/chat/completions" }
    let(:openai_response) do
      {
        id: "chatcmpl-123",
        model: "gpt-4o-mini-2024-07-18",
        choices: [ { message: { role: "assistant", content: "Looks good." } } ],
        usage: { prompt_tokens: 12, completion_tokens: 4, total_tokens: 16 }
      }
    end

    context "when the proxy token is missing" do
      let(:headers) do
        {
          "Accept" => "application/json",
          "X-Provider-Authorization" => provider_api_key
        }
      end

      it "returns 401 with an unauthorized error body" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(errors: [ { status: 401, detail: "Unauthorized" } ])
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end
    end

    context "when the proxy token is unknown" do
      let(:headers) do
        {
          "Accept" => "application/json",
          "Authorization" => "Bearer unknown-token",
          "X-Provider-Authorization" => provider_api_key
        }
      end

      it "returns 401" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(response_json).to eq(errors: [ { status: 401, detail: "Unauthorized" } ])
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end
    end

    context "when the proxy token is revoked" do
      let!(:proxy_token) { create(:proxy_token, :revoked) }

      it "returns 401" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(response_json).to eq(errors: [ { status: 401, detail: "Unauthorized" } ])
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end

      context "when the budget is also exceeded" do
        let!(:proxy_token) { create(:proxy_token, :revoked, :exceeded) }

        it "returns 401 (proxy auth runs before budget check)" do
          make_request

          expect(response).to have_http_status(:unauthorized)
        end
      end

      context "when X-Provider-Authorization is also missing" do
        let(:headers) do
          {
            "Accept" => "application/json",
            "Authorization" => "Bearer #{proxy_token.token}"
          }
        end

        it "returns 401 (proxy auth runs before credential check)" do
          make_request

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "when the token has remaining budget" do
      before do
        stub_request(:post, openai_endpoint)
          .to_return(
            status: 200,
            body: openai_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "forwards the request body to OpenAI" do
        make_request

        expect(WebMock).to have_requested(:post, openai_endpoint)
          .with(body: hash_including("model" => "gpt-4o-mini"))
      end

      it "forwards the caller's credential as Authorization to OpenAI" do
        make_request

        expect(WebMock).to have_requested(:post, openai_endpoint)
          .with(headers: { "Authorization" => "Bearer sk-test-provider-key" })
      end

      it "returns 200 with the OpenAI response body" do
        make_request

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(openai_response)
      end

      it "increments the token's usage_millicents" do
        expect { make_request }.to change { proxy_token.reload.usage_millicents }
      end

      context "when OpenAI returns an error" do
        before do
          stub_request(:post, openai_endpoint)
            .to_return(status: 500, body: { error: "upstream boom" }.to_json)
        end

        it "returns 502 with a formatted error body" do
          make_request

          expect(response).to have_http_status(:bad_gateway)
          expect(response_json[:errors].first[:status]).to eq(502)
        end

        it "does not increment the token's usage_millicents" do
          expect { make_request }.not_to change { proxy_token.reload.usage_millicents }
        end
      end
    end

    context "when the token budget is exceeded" do
      let!(:proxy_token) { create(:proxy_token, :exceeded) }

      it "returns 429 with a budget exceeded error body" do
        make_request

        expect(response).to have_http_status(:too_many_requests)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(errors: [ { status: 429, detail: "Budget exceeded" } ])
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end
    end

    context "when the token budget is exactly at the limit" do
      let!(:proxy_token) { create(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 1_000_000) }

      it "returns 429" do
        make_request

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    context "when the token budget is one cent under the limit" do
      let!(:proxy_token) { create(:proxy_token, limit_millicents: 1_000_000, usage_millicents: 999_999) }

      before do
        stub_request(:post, openai_endpoint)
          .to_return(
            status: 200,
            body: openai_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "allows the request through" do
        make_request

        expect(response).to have_http_status(:ok)
      end
    end

    context "when X-Provider-Authorization header is missing" do
      let(:headers) do
        {
          "Accept" => "application/json",
          "Authorization" => "Bearer #{proxy_token.token}"
        }
      end

      it "returns 401 with a missing-header error body" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(
          errors: [ { status: 401, detail: "Missing X-Provider-Authorization header" } ]
        )
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end

      context "when the budget is also exceeded" do
        let!(:proxy_token) { create(:proxy_token, :exceeded) }

        it "returns 401 (credential check runs before budget check)" do
          make_request

          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "when Authorization contains an OpenAI key instead of a proxy token" do
      let(:headers) do
        {
          "Accept" => "application/json",
          "Authorization" => "Bearer sk-test-provider-key"
        }
      end

      it "returns 401 — Authorization is for proxy auth, not the upstream credential" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(response_json).to eq(errors: [ { status: 401, detail: "Unauthorized" } ])
      end

      it "does not forward the request to OpenAI" do
        make_request

        expect(WebMock).not_to have_requested(:post, openai_endpoint)
      end
    end
  end

  describe "non-POST methods to /proxy" do
    let(:headers) { { "Accept" => "application/json" } }

    it "returns 404 for GET /proxy" do
      get "/proxy", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for PUT /proxy" do
      put "/proxy", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for DELETE /proxy" do
      delete "/proxy", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
