require "rails_helper"

RSpec.describe TokensController, type: :request do
  describe "POST #create /tokens" do
    subject(:make_request) { post "/tokens", params: params, as: :json }

    context "when email and limit are provided" do
      let(:params) { { email: "alice@example.com", limit: 10 } }

      it "returns 201" do
        make_request

        expect(response).to have_http_status(:created)
      end

      it "returns the token value" do
        make_request

        expect(response_json).to have_key(:token)
        expect(response_json[:token]).to be_present
      end

      it "returns application/json" do
        make_request

        expect(response.content_type).to include("application/json")
      end

      it "creates a ProxyToken with the email and limit" do
        expect { make_request }.to change { ProxyToken.count }.by(1)

        token = ProxyToken.last
        expect(token.email).to eq("alice@example.com")
        expect(token.limit_millicents).to eq(1_000_000)
      end

      context "when a label is also provided" do
        let(:params) { { email: "alice@example.com", limit: 10, label: "my production key" } }

        it "stores the label" do
          make_request

          expect(ProxyToken.last.label).to eq("my production key")
        end
      end

      context "when limit is a decimal (e.g. 10.50)" do
        let(:params) { { email: "alice@example.com", limit: 10.50 } }

        it "stores the correct millicents value" do
          make_request

          expect(ProxyToken.last.limit_millicents).to eq(1_050_000)
        end
      end

      context "when the same email registers twice" do
        it "creates a second token" do
          expect {
            post "/tokens", params: { email: "alice@example.com", limit: 10 }, as: :json
            post "/tokens", params: { email: "alice@example.com", limit: 10 }, as: :json
          }.to change { ProxyToken.count }.by(2)
        end
      end
    end

    context "when email is missing" do
      let(:params) { { limit: 10 } }

      it "returns 422" do
        make_request

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns an error pointing to email" do
        make_request

        expect(response_json[:errors].first[:source][:pointer]).to eq("/email")
      end

      it "does not create a ProxyToken" do
        expect { make_request }.not_to change { ProxyToken.count }
      end
    end

    context "when email format is invalid" do
      let(:params) { { email: "not-an-email", limit: 10 } }

      it "returns 422" do
        make_request

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a ProxyToken" do
        expect { make_request }.not_to change { ProxyToken.count }
      end
    end

    context "when limit is missing" do
      let(:params) { { email: "alice@example.com" } }

      it "returns 422" do
        make_request

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns an error pointing to limit" do
        make_request

        expect(response_json[:errors].first[:source][:pointer]).to eq("/limit")
      end

      it "does not create a ProxyToken" do
        expect { make_request }.not_to change { ProxyToken.count }
      end
    end

    context "when limit is zero or negative" do
      let(:params) { { email: "alice@example.com", limit: 0 } }

      it "returns 422" do
        make_request

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a ProxyToken" do
        expect { make_request }.not_to change { ProxyToken.count }
      end
    end

    context "when the endpoint is called without a proxy token in Authorization" do
      it "does not require proxy auth — the endpoint is public" do
        post "/tokens", params: { email: "alice@example.com", limit: 10 }, as: :json

        expect(response).not_to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET #index /tokens?email=" do
    let!(:token_one) { create(:proxy_token, email: "alice@example.com", label: "work", limit_millicents: 1_000_000, usage_millicents: 250_000) }
    let!(:token_two) { create(:proxy_token, email: "alice@example.com", label: "home", limit_millicents: 500_000, usage_millicents: 0) }
    let!(:other_token) { create(:proxy_token, email: "bob@example.com") }

    context "when email is provided" do
      subject(:make_request) { get "/tokens", params: { email: "alice@example.com" } }

      it "returns 200" do
        make_request

        expect(response).to have_http_status(:ok)
      end

      it "returns only tokens for that email" do
        make_request

        expect(response_json.length).to eq(2)
      end

      it "returns limit and usage in dollars" do
        make_request

        token = response_json.find { |t| t[:label] == "work" }
        expect(token[:limit]).to eq(10.0)
        expect(token[:usage]).to eq(2.5)
        expect(token[:remaining]).to eq(7.5)
      end

      it "does not return the token secret value" do
        make_request

        response_json.each do |t|
          expect(t).not_to have_key(:token)
        end
      end

      it "returns revoked status and created_at" do
        make_request

        token = response_json.first
        expect(token).to have_key(:revoked)
        expect(token).to have_key(:created_at)
      end

      it "returns an empty array when no tokens exist for that email" do
        get "/tokens", params: { email: "nobody@example.com" }

        expect(response).to have_http_status(:ok)
        expect(response_json).to eq([])
      end

      it "caps the response at 100 tokens" do
        101.times { create(:proxy_token, email: "many@example.com") }

        get "/tokens", params: { email: "many@example.com" }

        expect(response_json.length).to eq(100)
      end
    end

    context "when email is missing" do
      it "returns 422" do
        get "/tokens"

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "does not require proxy auth — the endpoint is public" do
      get "/tokens", params: { email: "alice@example.com" }

      expect(response).not_to have_http_status(:unauthorized)
    end
  end
end
