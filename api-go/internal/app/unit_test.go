package app

import (
	"encoding/json"
	"testing"
	"time"
)

func TestCurrentMonthKey(t *testing.T) {
	// 集計単位は UTC。日本時間で月をまたいでも、3実装で同じキーになる必要がある。
	jst := time.FixedZone("JST", 9*60*60)
	got := currentMonthKey(time.Date(2026, 10, 1, 5, 0, 0, 0, jst)) // UTCでは9月30日
	if got != "2026-09" {
		t.Errorf("JST 10/1 05:00 は UTC では9月。got=%q", got)
	}
	if got := currentMonthKey(time.Date(2026, 9, 4, 12, 0, 0, 0, time.UTC)); got != "2026-09" {
		t.Errorf("got=%q", got)
	}
}

func TestPlanLimit(t *testing.T) {
	if planLimit("free") != 5 || planLimit("pro") != 300 {
		t.Error("上限値が web/src/lib/plans.ts と食い違っている")
	}
	// 未知のプランは無料扱い。ここで落とさないのは、上限の強制はDB側が正本で、
	// この値は文言と表示にしか使わないため。
	if planLimit("enterprise") != 5 {
		t.Error("未知のプランが無料扱いになっていない")
	}
}

func TestLimitMessage(t *testing.T) {
	if got := limitMessage("free", 5); got != "今月の無料利用回数(5件)の上限に達しました。プロプランへのアップグレードをご検討ください" {
		t.Errorf("無料プランの文言が違う: %q", got)
	}
	if got := limitMessage("pro", 300); got != "今月の利用回数(300件)の上限に達しました" {
		t.Errorf("プロプランの文言が違う: %q", got)
	}
}

func TestValidReview(t *testing.T) {
	parse := func(t *testing.T, body string) generateRequest {
		t.Helper()
		var req generateRequest
		if err := json.Unmarshal([]byte(body), &req); err != nil {
			t.Fatalf("テストの入力が壊れている: %v", err)
		}
		return req
	}

	tests := []struct {
		name       string
		body       string
		wantOK     bool
		wantRating int
	}{
		{name: "通常", body: `{"review":{"reviewText":"スープが美味しかった","rating":5}}`, wantOK: true, wantRating: 5},
		{name: "ちょうど5文字は通る", body: `{"review":{"reviewText":"美味しいね","rating":3}}`, wantOK: true, wantRating: 3},
		// len()（バイト数）で数えると「美味」は6バイトで通ってしまう。
		// TypeScript版・Ruby版はどちらも文字数で数えるので、ここも文字数で数える。
		{name: "2文字の日本語は弾く", body: `{"review":{"reviewText":"美味","rating":5}}`},
		{name: "星が範囲外", body: `{"review":{"reviewText":"美味しかったです","rating":9}}`},
		{name: "星が0", body: `{"review":{"reviewText":"美味しかったです","rating":0}}`},
		{name: "星が小数", body: `{"review":{"reviewText":"美味しかったです","rating":4.5}}`},
		{name: "星が無い", body: `{"review":{"reviewText":"美味しかったです"}}`},
		{name: "reviewが無い", body: `{}`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rating, ok := validReview(parse(t, tt.body))
			if ok != tt.wantOK {
				t.Fatalf("ok=%v。期待は %v", ok, tt.wantOK)
			}
			if ok && rating != tt.wantRating {
				t.Fatalf("rating=%d。期待は %d", rating, tt.wantRating)
			}
		})
	}
}

func TestValidReviewLength(t *testing.T) {
	// 2000文字ちょうどは通り、2001文字は弾く
	var req generateRequest
	req.Review.Rating = "5"

	req.Review.ReviewText = repeat("あ", 2000)
	if _, ok := validReview(req); !ok {
		t.Error("2000文字が弾かれた")
	}
	req.Review.ReviewText = repeat("あ", 2001)
	if _, ok := validReview(req); ok {
		t.Error("2001文字が通ってしまった")
	}
}

func repeat(s string, n int) string {
	out := make([]byte, 0, len(s)*n)
	for range n {
		out = append(out, s...)
	}
	return string(out)
}
