require "rails_helper"

# Proof that RedactingFormatter catches the worst-case 500-path log line: an
# unhandled exception whose message embeds both bearer values. The formatter
# wraps Rails.logger system-wide, so anything logged via Rails.logger (request
# log, ActionDispatch::DebugExceptions, future log shippers) passes through it.
RSpec.describe "Log scrubbing on 500 errors in POST /proxy", type: :request do
  let!(:proxy_token) { create(:proxy_token) }
  let(:proxy_bearer) { proxy_token.token }
  let(:provider_bearer) { "sk-test-provider-secret-key-1234567890" }
  let(:headers) do
    {
      "Accept" => "application/json",
      "Authorization" => "Bearer #{proxy_bearer}",
      "X-Provider-Authorization" => "Bearer #{provider_bearer}"
    }
  end
  let(:body) { { model: "gpt-4o-mini", messages: [ { role: "user", content: "hi" } ] } }

  # Test env's default re-raises StandardError out of the request via
  # ActionDispatch::ShowExceptions. Override per-request through env_config
  # (the middleware reads from `env`, not from config, at request time) so
  # the request produces a real 500 — matching production — and the spec
  # can inspect what DebugExceptions logged on the way through.
  around do |example|
    key = "action_dispatch.show_exceptions"
    original = Rails.application.env_config[key]
    Rails.application.env_config[key] = :all
    example.run
  ensure
    Rails.application.env_config[key] = original
  end

  it "redacts both bearer values from the logged exception when the proxy action raises" do
    leaky_message =
      "boom: Authorization: Bearer #{proxy_bearer}; " \
      "X-Provider-Authorization: Bearer #{provider_bearer}"
    allow_any_instance_of(OpenAiClient).to receive(:chat_completion).and_raise(StandardError, leaky_message)

    captured = capture_rails_log do
      post "/proxy", params: body, headers: headers, as: :json
    end

    expect(response).to have_http_status(:internal_server_error)
    expect(captured).to include("[REDACTED]")
    expect(captured).not_to include(proxy_bearer)
    expect(captured).not_to include(provider_bearer)
  end

  # Attach a StringIO sink to Rails.logger via BroadcastLogger so we capture
  # what other subsystems (DebugExceptions logs via ActionView::Base.logger,
  # which was set to the same logger at boot) actually emit. The sink uses
  # the same RedactingFormatter as production so the assertion exercises the
  # real redaction path.
  def capture_rails_log
    io = StringIO.new
    sink = Logger.new(io)
    sink.formatter = RedactingFormatter.new(sink.formatter || Logger::Formatter.new)
    Rails.logger.broadcast_to(sink)
    yield
    io.string
  ensure
    Rails.logger.stop_broadcasting_to(sink) if sink
  end
end
