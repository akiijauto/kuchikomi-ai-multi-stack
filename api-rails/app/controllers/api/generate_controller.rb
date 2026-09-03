module Api
  # web/src/app/api/generate/route.ts の移植。
  # ステータスコードと文言をNext.js版に合わせてある（同じ画面から呼べるように）。
  class GenerateController < BaseController
    def create
      body = json_body
      return bad_request("不正なリクエストです") if body.nil?

      review = body["review"]
      return bad_request("入力内容を確認してください") unless valid_review?(review)

      profile = Profile.find_by(id: current_user_id)
      if profile.nil? || profile.store_name.to_s.empty?
        return bad_request("先にお店のプロフィールを設定してください")
      end

      limit = Plans::LIMITS.fetch(profile.plan, Plans::LIMITS["free"])
      new_count = UsageCounter.increment!(user_id: current_user_id, month: Plans.current_month_key)

      result = ReplyGenerator.new(
        profile: profile,
        review_text: review["reviewText"],
        rating: review["rating"]
      ).call

      render json: {
        replies: result.replies,
        mock: result.mock,
        usage: { used: new_count, limit: limit }
      }
    rescue UsageCounter::LimitExceeded
      render json: { error: limit_message(profile) }, status: :too_many_requests
    rescue UsageCounter::PlanNotFound
      # プロフィール行が無い・未知のプラン。DB側が加算を拒否している
      bad_request("先にお店のプロフィールを設定してください")
    rescue StandardError => e
      Rails.logger.error("generation failed: #{e.class}: #{e.message}")
      render json: { error: "生成に失敗しました。時間をおいて再度お試しください" },
             status: :internal_server_error
    end

    private

    def valid_review?(review)
      return false unless review.is_a?(Hash)

      text = review["reviewText"]
      rating = review["rating"]
      text.is_a?(String) && text.length >= 5 && text.length <= 2000 &&
        rating.is_a?(Integer) && (1..5).cover?(rating)
    end

    def limit_message(profile)
      limit = Plans::LIMITS.fetch(profile&.plan || "free", Plans::LIMITS["free"])
      if profile&.plan == "free"
        "今月の無料利用回数(#{limit}件)の上限に達しました。プロプランへのアップグレードをご検討ください"
      else
        "今月の利用回数(#{limit}件)の上限に達しました"
      end
    end

    def bad_request(message)
      render json: { error: message }, status: :bad_request
    end
  end
end
