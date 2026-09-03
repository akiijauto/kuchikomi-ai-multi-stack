Rails.application.routes.draw do
  # Next.js版と同じURLに合わせる（/api/generate, /api/profile, /api/health）
  scope "/api" do
    get  "health",   to: "api/health#show"
    post "generate", to: "api/generate#create"
    post "profile",  to: "api/profiles#create"

    # デモ用のトークン発行。本番では絶対に生やさない。
    # 環境変数で明示的に有効化したときだけ経路そのものが存在する状態にしてある
    # （コントローラ側で弾く形にすると、設定を間違えたときに口が開いたままになる）。
    post "demo/token", to: "api/demo#token" if ENV["DEMO_MODE"] == "1"
  end

  root to: redirect("/demo.html")
end
