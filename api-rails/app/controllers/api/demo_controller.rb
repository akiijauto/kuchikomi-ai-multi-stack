module Api
  # デモ画面用にトークンを発行するだけの入口。
  #
  # なぜ必要か: このアプリの本来の利用者はSupabaseでログインし、
  # そこで発行されたトークンを持ってくる。デモではSupabaseが無いので、
  # 同じ形のトークンをこちら側で作る。
  #
  # なぜ既定で無効にしてあるか: これは「誰でもログイン済みになれる入口」であり、
  # 本番に存在してはいけない。DEMO_MODE=1 のときだけ routes.rb で有効になる。
  class DemoController < ApplicationController
    def token
      user_id = ensure_demo_user
      secret = ENV.fetch("SUPABASE_JWT_SECRET")
      jwt = JWT.encode(
        { sub: user_id, aud: "authenticated", exp: Time.now.to_i + 900 },
        secret,
        "HS256"
      )
      render json: { token: jwt, expires_in: 900 }
    end

    private

    DEMO_USER_ID = "00000000-0000-4000-8000-000000000001".freeze

    def ensure_demo_user
      conn = ActiveRecord::Base.connection
      conn.execute(
        "insert into auth.users (id, email) values ('#{DEMO_USER_ID}', 'demo@example.test') " \
        "on conflict (id) do nothing"
      )
      # profiles の行は on_auth_user_created トリガーが作る。店名だけ入れておく
      profile = Profile.find_by(id: DEMO_USER_ID)
      profile&.update!(store_name: "デモ食堂", industry: "飲食店", tone: "friendly", signature: "店主 デモ")
      DEMO_USER_ID
    end
  end
end
