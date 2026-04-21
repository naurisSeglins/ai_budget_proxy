module RequestSpecHelper
  def response_json
    JSON.parse(response.body, symbolize_names: true)
  end
end

RSpec.configure do |config|
  config.include RequestSpecHelper, type: :request
end
