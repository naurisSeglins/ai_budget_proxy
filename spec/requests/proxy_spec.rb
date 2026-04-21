require "rails_helper"

RSpec.describe ProxyController, type: :request do
  describe "POST #create /proxy" do
    subject(:make_request) { post "/proxy", headers: headers, params: params, as: :json }

    let(:headers) { { "Accept" => "application/json" } }
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

    context "when a valid OpenAI-shaped request is proxied" do
      let(:expected_response) do
        {
          status: "ok",
          message: "proxy is running",
          request: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: "You are a code review assistant." },
              { role: "user", content: "Review this Ruby method for performance issues." }
            ],
            temperature: 0.7,
            max_tokens: 500
          }
        }
      end

      it "responds with 200 and echoes the proxied request back as JSON" do
        make_request

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(expected_response)
      end
    end

    context "when the request body is empty" do
      let(:params) { {} }

      let(:expected_response) do
        {
          status: "ok",
          message: "proxy is running",
          request: {}
        }
      end

      it "responds with 200 and an empty request echo" do
        make_request

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("application/json")
        expect(response_json).to eq(expected_response)
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
