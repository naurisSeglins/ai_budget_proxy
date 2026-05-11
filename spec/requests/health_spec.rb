require "rails_helper"

RSpec.describe "GET /up", type: :request do
  it "returns 200 when the database is reachable" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end

  it "returns 503 when the database connection fails" do
    allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(
      ActiveRecord::ConnectionNotEstablished
    )

    get "/up"

    expect(response).to have_http_status(:service_unavailable)
  end

  it "is publicly accessible (no Authorization header required)" do
    get "/up"

    expect(response).not_to have_http_status(:unauthorized)
  end
end
