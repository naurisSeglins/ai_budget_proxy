require "rails_helper"

RSpec.describe "Log filtering on POST /proxy", type: :request do
  let!(:proxy_token) { create(:proxy_token) }
  let(:secret_prompt) { "TOPSECRETPROMPTabc123" }
  let(:headers) do
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{proxy_token.token}",
      "X-Provider-Authorization" => "Bearer sk-test-provider-key"
    }
  end
  let(:openai_endpoint) { "https://api.openai.com/v1/chat/completions" }
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

  # Capture the params payload that Rails publishes to ActionController log subscribers
  # — this is the same already-filtered hash that produces the "Parameters: …" log line.
  def capture_filtered_params(&block)
    captured = nil
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*args|
      captured = ActiveSupport::Notifications::Event.new(*args).payload[:params]
    end
    block.call
    captured
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  it "redacts :messages content in the params Rails logs" do
    body = { model: "gpt-4o-mini", messages: [ { role: "user", content: secret_prompt } ] }

    params = capture_filtered_params do
      post "/proxy", params: body, headers: headers, as: :json
    end

    expect(params).to include("messages" => "[FILTERED]")
    expect(params.to_s).not_to include(secret_prompt)
  end

  it "redacts :prompt, :input, and :content fields too (covers other provider shapes)" do
    [ :prompt, :input, :content ].each do |field|
      body = { model: "gpt-4o-mini", field => "leak-#{field}-value" }

      params = capture_filtered_params do
        post "/proxy", params: body, headers: headers, as: :json
      end

      expect(params.to_s).not_to(include("leak-#{field}-value"),
        "expected :#{field} to be filtered but got: #{params.inspect}")
    end
  end
end
