require "rails_helper"

RSpec.describe OpenAiClient do
  let(:api_key) { "test-api-key" }
  let(:client) { described_class.new(api_key: api_key) }
  let(:endpoint) { "https://api.openai.com/v1/chat/completions" }
  let(:payload) do
    {
      model: "gpt-4o-mini",
      messages: [ { role: "user", content: "hello" } ]
    }
  end

  describe "#chat_completion" do
    context "when OpenAI returns a 200 response" do
      let(:openai_response) do
        {
          id: "chatcmpl-123",
          choices: [ { message: { role: "assistant", content: "hi there" } } ],
          usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
        }
      end

      before do
        stub_request(:post, endpoint)
          .with(
            headers: {
              "Authorization" => "Bearer #{api_key}",
              "Content-Type" => "application/json"
            },
            body: payload.to_json
          )
          .to_return(
            status: 200,
            body: openai_response.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "posts the payload to OpenAI with the correct headers and body" do
        client.chat_completion(payload)

        expect(WebMock).to have_requested(:post, endpoint)
          .with(
            headers: {
              "Authorization" => "Bearer #{api_key}",
              "Content-Type" => "application/json"
            },
            body: payload.to_json
          )
      end

      it "returns the parsed JSON response" do
        expect(client.chat_completion(payload)).to eq(openai_response.deep_stringify_keys)
      end
    end

    context "when OpenAI returns a non-200 response" do
      before do
        stub_request(:post, endpoint)
          .to_return(status: 401, body: { error: { message: "Incorrect API key provided: sk-test..." } }.to_json)
      end

      it "raises OpenAiClient::Error" do
        expect { client.chat_completion(payload) }.to raise_error(OpenAiClient::Error)
      end

      it "error message contains only the status code, not the response body" do
        expect { client.chat_completion(payload) }
          .to raise_error(OpenAiClient::Error, "OpenAI returned 401")
      end

      it "logs only the status code at error level, not the response body" do
        allow(Rails.logger).to receive(:error)
        begin
          client.chat_completion(payload)
        rescue OpenAiClient::Error
          nil
        end
        expect(Rails.logger).to have_received(:error).with("OpenAI returned 401")
      end
    end

    context "when a Faraday::SSLError is raised" do
      before do
        stub_request(:post, endpoint)
          .to_raise(Faraday::SSLError.new("SSL_read: unexpected eof while reading"))
      end

      it "raises OpenAiClient::Error" do
        expect { client.chat_completion(payload) }.to raise_error(OpenAiClient::Error)
      end

      it "error message contains only the exception class, not the SSL error detail" do
        expect { client.chat_completion(payload) }
          .to raise_error(OpenAiClient::Error, "OpenAI request failed: Faraday::SSLError")
      end

      it "logs only the exception class at error level, not the error detail" do
        allow(Rails.logger).to receive(:error)
        begin
          client.chat_completion(payload)
        rescue OpenAiClient::Error
          nil
        end
        expect(Rails.logger).to have_received(:error).with("OpenAI network error: Faraday::SSLError")
      end
    end

    context "when a Faraday::TimeoutError is raised" do
      before do
        stub_request(:post, endpoint).to_raise(Faraday::TimeoutError)
      end

      it "raises OpenAiClient::Error" do
        expect { client.chat_completion(payload) }.to raise_error(OpenAiClient::Error)
      end
    end
  end

  describe "API key resolution" do
    it "raises ArgumentError when api_key is not provided" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it "raises MissingApiKeyError when api_key is nil" do
      expect { described_class.new(api_key: nil) }.to raise_error(OpenAiClient::MissingApiKeyError)
    end

    it "raises MissingApiKeyError when api_key is blank" do
      expect { described_class.new(api_key: "") }.to raise_error(OpenAiClient::MissingApiKeyError)
    end
  end
end
