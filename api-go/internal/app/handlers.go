package app

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"time"
	"unicode/utf8"

	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/auth"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/reply"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/store"
)

// handleHealth は死活監視。Next.js版・Rails版と同じく、認証基盤にもDBにも依存させない。
// ここがDBを見に行くと「アプリは生きているがDBが不調」でコンテナごと落とされ、
// 切り分けができなくなる。
func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"status": "ok",
		"uptime": time.Since(s.startedAt).Seconds(),
	})
}

type generateRequest struct {
	Review struct {
		ReviewText string      `json:"reviewText"`
		Rating     json.Number `json:"rating"`
	} `json:"review"`
}

type usageBody struct {
	Used  int `json:"used"`
	Limit int `json:"limit"`
}

type generateResponse struct {
	Replies []reply.Reply `json:"replies"`
	Mock    bool          `json:"mock"`
	Usage   usageBody     `json:"usage"`
}

// handleGenerate は web/src/app/api/generate/route.ts の移植。
// ステータスコードと文言をNext.js版・Rails版に合わせてある。
func (s *Server) handleGenerate(w http.ResponseWriter, r *http.Request, userID string) {
	ctx := r.Context()

	// 「JSONとして壊れている」と「JSONではあるが形が違う」を分けて返す。
	// 他の2実装が別の文言を返しているので、ここも合わせる。
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
	if err != nil {
		s.badRequest(w, "不正なリクエストです")
		return
	}
	if !json.Valid(raw) {
		s.badRequest(w, "不正なリクエストです")
		return
	}
	var req generateRequest
	if err := json.Unmarshal(raw, &req); err != nil {
		s.badRequest(w, "入力内容を確認してください")
		return
	}

	rating, ok := validReview(req)
	if !ok {
		s.badRequest(w, "入力内容を確認してください")
		return
	}

	profile, err := s.store.Profile(ctx, userID)
	if errors.Is(err, store.ErrProfileNotFound) || (err == nil && profile.StoreName == "") {
		s.badRequest(w, "先にお店のプロフィールを設定してください")
		return
	}
	if err != nil {
		s.log.Error("プロフィールの取得に失敗", "error", err)
		s.internalError(w)
		return
	}

	limit := planLimit(profile.Plan)

	// 上限チェックと加算はDB関数の中で原子的に行う(同時リクエストでも上限を超えない)。
	used, err := s.store.IncrementUsage(ctx, userID, currentMonthKey(time.Now()))
	switch {
	case errors.Is(err, store.ErrLimitExceeded):
		writeJSON(w, http.StatusTooManyRequests, errorBody{Error: limitMessage(profile.Plan, limit)})
		return
	case errors.Is(err, store.ErrPlanNotFound):
		// プロフィール行が無い・未知のプラン。DB側が加算を拒否している
		s.badRequest(w, "先にお店のプロフィールを設定してください")
		return
	case err != nil:
		s.log.Error("利用回数の加算に失敗", "error", err)
		s.internalError(w)
		return
	}

	result, err := s.gen.Generate(ctx, reply.Profile{
		StoreName: profile.StoreName,
		Industry:  profile.Industry,
		Tone:      profile.Tone,
		Signature: profile.Signature,
	}, reply.Review{Text: req.Review.ReviewText, Rating: rating})
	if err != nil {
		s.log.Error("生成に失敗", "error", err)
		s.internalError(w)
		return
	}

	writeJSON(w, http.StatusOK, generateResponse{
		Replies: result.Replies,
		Mock:    result.Mock,
		Usage:   usageBody{Used: used, Limit: limit},
	})
}

// validReview は入力検証。星の値も返す。
//
// 文字数を len() で数えないのが要点。len() はバイト数なので、
// 日本語だと「美味」(6バイト)が5文字以上と判定されてしまい、
// TypeScript版・Ruby版(どちらも文字数で数える)と挙動が食い違う。
// 同じ入力に同じ答えを返すことがこの演習の眼目なので、文字数で数える。
func validReview(req generateRequest) (int, bool) {
	n := utf8.RuneCountInString(req.Review.ReviewText)
	if n < 5 || n > 2000 {
		return 0, false
	}
	// json.Number をそのまま整数として読む。"5.0" や "5" という文字列は
	// ここで弾かれ、Ruby版(Integerであることを要求)と同じ結果になる。
	rating, err := strconv.Atoi(req.Review.Rating.String())
	if err != nil || rating < 1 || rating > 5 {
		return 0, false
	}
	return rating, true
}

func (s *Server) internalError(w http.ResponseWriter) {
	writeJSON(w, http.StatusInternalServerError,
		errorBody{Error: "生成に失敗しました。時間をおいて再度お試しください"})
}

// demoUserID はデモ画面用の固定利用者。Rails版と同じIDを使う
// (同じDBを見たときに行が増えないほうが確かめやすい)。
const demoUserID = "00000000-0000-4000-8000-000000000001"

// handleDemoToken はデモ画面用にトークンを発行する。
// 本来の利用者はSupabaseでログインして得たトークンを持ってくる。
// デモではSupabaseが無いので、同じ形のトークンをこちらで作る。
func (s *Server) handleDemoToken(w http.ResponseWriter, r *http.Request) {
	if err := s.store.EnsureDemoUser(r.Context(), demoUserID, store.Profile{
		StoreName: "デモ食堂", Industry: "飲食店", Tone: "friendly", Signature: "店主 デモ",
	}); err != nil {
		s.log.Error("デモ用利用者の準備に失敗", "error", err)
		s.internalError(w)
		return
	}
	const ttl = 15 * time.Minute
	token, err := auth.Issue(demoUserID, s.cfg.JWTSecret, ttl)
	if err != nil {
		s.log.Error("デモ用トークンの発行に失敗", "error", err)
		s.internalError(w)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"token": token, "expires_in": int(ttl.Seconds()),
	})
}
