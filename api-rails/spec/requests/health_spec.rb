require "rails_helper"

RSpec.describe "GET /api/health", type: :request do
  it "認証なしで200を返す（死活監視は認証基盤に依存させない）" do
    get "/api/health"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["status"]).to eq("ok")
  end
end
