# 画面表示・エラー文言用の複製。上限の強制はDB側(plan_limits)が正本。
# web/src/lib/plans.ts と同じ値を持つ。変更するときは両方を直す。
module Plans
  LIMITS = { "free" => 5, "pro" => 300 }.freeze

  # 利用回数の集計単位(YYYY-MM、UTC基準)。TypeScript版の currentMonthKey と同じ
  def self.current_month_key(time = Time.now.utc)
    time.utc.strftime("%Y-%m")
  end
end
