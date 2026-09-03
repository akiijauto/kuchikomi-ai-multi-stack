// Package app は HTTP の口(ルーティング・認証・入力検証・応答)を組み立てる。
//
// ルータのライブラリは入れていない。Go 1.22 以降の http.ServeMux は
// "POST /api/generate" のようにメソッド込みのパターンを扱えるので、
// この規模なら標準ライブラリだけで足りる。依存を足さない判断も含めて記録に残す。
package app

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/auth"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/reply"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/store"
)

// Config はサーバの設定。すべて環境変数から来る(cmd/api/main.go で読む)。
type Config struct {
	Addr      string
	JWTSecret string
	PublicDir string
	// DemoMode が真のときだけ、デモ用トークンの発行口が「存在する」。
	// ハンドラの中で判定する形にすると、設定を間違えたときに口が開いたままになる。
	// これは「誰でもログイン済みになれる入口」なので、無いことが保証される側に倒す。
	DemoMode bool
}

// Server はルーティングと依存をまとめたもの。
type Server struct {
	cfg       Config
	store     *store.Store
	gen       reply.Generator
	log       *slog.Logger
	startedAt time.Time
	handler   http.Handler
}

// New はハンドラを組み立てて返す。
func New(cfg Config, st *store.Store, gen reply.Generator, log *slog.Logger) *Server {
	s := &Server{cfg: cfg, store: st, gen: gen, log: log, startedAt: time.Now()}

	mux := http.NewServeMux()
	// Next.js版・Rails版と同じURLに合わせる。
	mux.HandleFunc("GET /api/health", s.handleHealth)
	mux.HandleFunc("POST /api/generate", s.withAuth(s.handleGenerate))
	if cfg.DemoMode {
		mux.HandleFunc("POST /api/demo/token", s.handleDemoToken)
	}

	if cfg.PublicDir != "" {
		files := http.FileServer(http.Dir(cfg.PublicDir))
		// "{$}" は「ちょうど / のとき」を表す(Go 1.22 のパターン)。
		mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
			http.Redirect(w, r, "/demo.html", http.StatusFound)
		})
		mux.Handle("GET /", files)
	}

	s.handler = s.withLogging(mux)
	return s
}

// ServeHTTP により Server 自身がハンドラとして使える。
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) { s.handler.ServeHTTP(w, r) }

// withLogging は1リクエスト1行のログを出す。
//
// Content-Length を必ず出しているのは 2026-09-03 の教訓による。
// Rails版で「日本語のときだけ400」が起き、原因はアプリではなく
// 送信側のシェルが UTF-8 以外で送っていたことだった。
// 受け取ったバイト数が記録されていたおかげで切り分けられた。
func (s *Server) withLogging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		s.log.Info("request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"req_content_length", r.ContentLength,
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// withAuth は認証を通したハンドラを作る。利用者IDを引数で渡す形にして、
// context への詰め替えを挟まない(この規模では型が見えているほうが追いやすい)。
func (s *Server) withAuth(next func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := auth.BearerToken(r)
		if token == "" {
			s.unauthorized(w)
			return
		}
		if s.cfg.JWTSecret == "" {
			// 設定漏れを「ログインが必要です」で隠すと原因が追えなくなるので分けて返す。
			s.log.Error("SUPABASE_JWT_SECRET が未設定のため検証できない")
			writeJSON(w, http.StatusInternalServerError, errorBody{Error: "サーバー設定に誤りがあります"})
			return
		}
		userID, err := auth.Verify(token, s.cfg.JWTSecret)
		if err != nil {
			s.unauthorized(w)
			return
		}
		next(w, r, userID)
	}
}

type errorBody struct {
	Error string `json:"error"`
}

func (s *Server) unauthorized(w http.ResponseWriter) {
	writeJSON(w, http.StatusUnauthorized, errorBody{Error: "ログインが必要です"})
}

func (s *Server) badRequest(w http.ResponseWriter, message string) {
	writeJSON(w, http.StatusBadRequest, errorBody{Error: message})
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	// ここで失敗しても、ヘッダは既に送っているのでやり直せない。記録だけ残す。
	if err := json.NewEncoder(w).Encode(body); err != nil {
		slog.Error("応答の書き出しに失敗", "error", err)
	}
}
