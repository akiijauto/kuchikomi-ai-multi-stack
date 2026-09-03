module Api
  # 認証つきエンドポイントの共通処理。
  #
  # Next.js版は supabase-js の `auth.getUser()` が裏でトークンを検証している。
  # Railsにはその依存が無いので、Supabaseが発行したJWTを自前で検証する。
  # やっていることは同じで、「署名が正しいか」と「誰なのか(sub)」を取り出すだけ。
  class BaseController < ApplicationController
    before_action :authenticate!

    private

    attr_reader :current_user_id

    def authenticate!
      token = bearer_token
      return unauthorized if token.blank?

      secret = ENV["SUPABASE_JWT_SECRET"]
      if secret.blank?
        # 設定漏れを「ログインが必要です」で隠すと原因が追えなくなるので分けて返す
        Rails.logger.error("SUPABASE_JWT_SECRET が未設定のため検証できない")
        return render json: { error: "サーバー設定に誤りがあります" }, status: :internal_server_error
      end

      payload, = JWT.decode(token, secret, true, { algorithm: "HS256" })
      @current_user_id = payload["sub"]
      unauthorized if @current_user_id.blank?
    rescue JWT::DecodeError
      # 期限切れ・改ざん・別の鍵で署名、いずれもここに来る。
      # 利用者にはどれかを教えない（攻撃者への情報提供になるため）
      unauthorized
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      return nil unless header.start_with?("Bearer ")

      header.delete_prefix("Bearer ").strip
    end

    def unauthorized
      render json: { error: "ログインが必要です" }, status: :unauthorized
    end

    def json_body
      @json_body ||= JSON.parse(request.raw_post)
    rescue JSON::ParserError
      nil
    end
  end
end
