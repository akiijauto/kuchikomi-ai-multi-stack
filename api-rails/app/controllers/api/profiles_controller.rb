module Api
  # web/src/app/api/profile/route.ts の移植。
  class ProfilesController < BaseController
    TONES = Profile::TONES

    def create
      body = json_body
      return bad_request("不正なリクエストです") if body.nil?
      return bad_request("入力内容を確認してください") unless valid?(body)

      # 更新対象を自分の行に限定する。
      # 本番のSupabaseはRLSが最後の砦になるが、Railsは接続ロールが
      # テーブル所有者だとRLSを素通りする。ここで絞るのは飾りではない。
      profile = Profile.find_by(id: current_user_id)
      return bad_request("入力内容を確認してください") if profile.nil?

      profile.update!(
        store_name: body["storeName"],
        industry: body["industry"],
        tone: body["tone"],
        signature: body["signature"].to_s
      )
      render json: { ok: true }
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("profile update failed: #{e.class}: #{e.message}")
      render json: { error: "保存に失敗しました。時間をおいて再度お試しください" },
             status: :internal_server_error
    end

    private

    def valid?(body)
      return false unless body.is_a?(Hash)

      store_name = body["storeName"]
      industry = body["industry"]
      tone = body["tone"]
      signature = body["signature"]

      store_name.is_a?(String) && (1..50).cover?(store_name.length) &&
        industry.is_a?(String) && (1..30).cover?(industry.length) &&
        TONES.include?(tone) &&
        (signature.nil? || (signature.is_a?(String) && signature.length <= 30))
    end

    def bad_request(message)
      render json: { error: message }, status: :bad_request
    end
  end
end
