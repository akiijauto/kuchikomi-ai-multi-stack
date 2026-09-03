package app

import (
	"fmt"
	"time"
)

// planLimits は画面表示・エラー文言用の複製。上限の強制は DB 側(plan_limits)が正本。
// web/src/lib/plans.ts / api-rails の Plans と同じ値を持つ。変えるときは全部を直す。
var planLimits = map[string]int{"free": 5, "pro": 300}

func planLimit(plan string) int {
	if limit, ok := planLimits[plan]; ok {
		return limit
	}
	return planLimits["free"]
}

// currentMonthKey は利用回数の集計単位(YYYY-MM、UTC基準)。
// TypeScript版の currentMonthKey / Ruby版の Plans.current_month_key と同じ。
func currentMonthKey(t time.Time) string {
	return t.UTC().Format("2006-01")
}

func limitMessage(plan string, limit int) string {
	if plan == "free" {
		return fmt.Sprintf("今月の無料利用回数(%d件)の上限に達しました。プロプランへのアップグレードをご検討ください", limit)
	}
	return fmt.Sprintf("今月の利用回数(%d件)の上限に達しました", limit)
}
