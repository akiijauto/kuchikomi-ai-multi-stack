# 月間利用回数の加算と上限チェック。
#
# 重要: 上限の判定はRuby側でやらない。DBの public.increment_usage を呼ぶ。
# 「読んでから書く」を分けて書くと、同時に2本来たときに上限を超えられる。
# DB関数は1文の中で判定と加算を行うので、実装言語が何であっても超えない。
# Next.js版と同じ関数を呼んでいるので、上限の挙動は自動的に一致する。
class UsageCounter
  class LimitExceeded < StandardError; end
  class PlanNotFound < StandardError; end

  # @return [Integer] 加算後の今月の利用回数
  def self.increment!(user_id:, month:)
    connection.transaction do
      # increment_usage の中の auth.uid() が読む値を立てる。
      # 第3引数 true はトランザクション内だけ有効という意味で、
      # 接続を使い回しても他のリクエストへ漏れない。
      exec(
        "select set_config('request.jwt.claim.sub', $1, true)",
        [ text_param("sub", user_id) ]
      )
      row = exec("select public.increment_usage($1) as count", [ text_param("month", month) ])
      row.first["count"]
    end
  rescue ActiveRecord::StatementInvalid => e
    case sqlstate(e)
    when "P0001" then raise LimitExceeded
    when "P0002" then raise PlanNotFound
    else raise
    end
  end

  def self.connection
    ActiveRecord::Base.connection
  end
  private_class_method :connection

  def self.exec(sql, params)
    connection.exec_query(sql, "UsageCounter", params)
  end
  private_class_method :exec

  def self.text_param(name, value)
    ActiveRecord::Relation::QueryAttribute.new(name, value, ActiveRecord::Type::String.new)
  end
  private_class_method :text_param

  # PostgreSQL のエラーコードを取り出す。
  # メッセージ文字列で判定すると、文言を変えた瞬間に壊れる。
  def self.sqlstate(error)
    cause = error.cause
    return nil unless cause.respond_to?(:result) && cause.result

    cause.result.error_field(PG::Result::PG_DIAG_SQLSTATE)
  end
  private_class_method :sqlstate
end
