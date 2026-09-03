require "rails_helper"

RSpec.describe "POST /api/profile", type: :request do
  let(:valid_body) do
    { storeName: "ラーメン太郎", industry: "飲食店", tone: "friendly", signature: "店主" }
  end

  it "トークンが無ければ401" do
    post "/api/profile", params: valid_body.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["error"]).to eq("ログインが必要です")
  end

  it "別の鍵で署名されたトークンは401（署名を検証している証拠）" do
    user_id = create_user_with_profile
    headers = auth_header(user_id, secret: "another-secret-entirely").merge("Content-Type" => "application/json")
    post "/api/profile", params: valid_body.to_json, headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it "期限切れのトークンは401" do
    user_id = create_user_with_profile
    headers = auth_header(user_id, exp: Time.now.to_i - 60).merge("Content-Type" => "application/json")
    post "/api/profile", params: valid_body.to_json, headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it "未知のtoneは400（DBのCHECK制約に到達する前に弾く）" do
    user_id = create_user_with_profile
    headers = auth_header(user_id).merge("Content-Type" => "application/json")
    post "/api/profile", params: valid_body.merge(tone: "angry").to_json, headers: headers
    expect(response).to have_http_status(:bad_request)
  end

  it "正しい入力なら保存され、自分の行だけが変わる" do
    me = create_user_with_profile(store_name: "変更前")
    other = create_user_with_profile(store_name: "他人の店")
    headers = auth_header(me).merge("Content-Type" => "application/json")

    post "/api/profile", params: valid_body.to_json, headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq({ "ok" => true })
    expect(Profile.find(me).store_name).to eq("ラーメン太郎")
    expect(Profile.find(other).store_name).to eq("他人の店")
  end
end
