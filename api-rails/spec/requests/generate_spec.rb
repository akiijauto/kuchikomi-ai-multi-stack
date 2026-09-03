require "rails_helper"

RSpec.describe "POST /api/generate", type: :request do
  let(:body) { { review: { reviewText: "スープが本当に美味しかったです", rating: 5 } } }

  def post_generate(user_id, payload = body)
    post "/api/generate",
         params: payload.to_json,
         headers: auth_header(user_id).merge("Content-Type" => "application/json")
  end

  it "トークンが無ければ401" do
    post "/api/generate", params: body.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "口コミが短すぎれば400" do
    user_id = create_user_with_profile
    post_generate(user_id, { review: { reviewText: "美味", rating: 5 } })
    expect(response).to have_http_status(:bad_request)
  end

  it "星の値が範囲外なら400" do
    user_id = create_user_with_profile
    post_generate(user_id, { review: { reviewText: "とても良かったです", rating: 9 } })
    expect(response).to have_http_status(:bad_request)
  end

  it "店名が未設定なら400" do
    user_id = create_user_with_profile(store_name: "")
    post_generate(user_id)
    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)["error"]).to include("プロフィール")
  end

  it "APIキーが無ければデモ返信を3案返し、利用回数が1つ増える" do
    user_id = create_user_with_profile(signature: "店主 太郎")
    post_generate(user_id)

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["mock"]).to be(true)
    expect(json["replies"].size).to eq(3)
    expect(json["replies"].first["text"]).to include("店主 太郎")
    expect(json["usage"]).to eq({ "used" => 1, "limit" => 5 })
  end

  it "無料プランの上限(5件)を超えると429を返し、6件目は加算されない" do
    user_id = create_user_with_profile(plan: "free")

    5.times { post_generate(user_id) }
    expect(response).to have_http_status(:ok)

    post_generate(user_id)
    expect(response).to have_http_status(:too_many_requests)
    expect(JSON.parse(response.body)["error"]).to include("上限に達しました")

    count = ActiveRecord::Base.connection.select_value(
      "select count from public.usage_logs where user_id = '#{user_id}'"
    )
    expect(count).to eq(5)
  end

  it "プロプランは無料プランの上限を超えても通る" do
    user_id = create_user_with_profile(plan: "pro")
    6.times { post_generate(user_id) }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["usage"]).to eq({ "used" => 6, "limit" => 300 })
  end

  it "星1の口コミには謝罪側のデモ返信が返る" do
    user_id = create_user_with_profile
    post_generate(user_id, { review: { reviewText: "料理が冷めていて残念でした", rating: 1 } })
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["replies"].first["text"]).to include("申し訳ございません")
  end
end
