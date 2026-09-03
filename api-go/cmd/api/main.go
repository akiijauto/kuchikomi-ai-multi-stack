// Command api は「クチコミ返信AI」の Go 実装。
//
// Next.js の API Routes / Rails API と同じエンドポイントを提供する。
// 同じスキーマ(web/supabase/schema.sql)に対して3つ目の実装を載せるのが目的。
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/app"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/reply"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/store"
)

func main() {
	// 実行イメージにシェルもcurlも入れていないので、コンテナの死活監視は
	// 「このバイナリ自身に自分を叩かせる」形にする(HEALTHCHECK から呼ぶ)。
	healthcheck := flag.Bool("healthcheck", false, "自分のヘルスチェックを叩いて終了コードで返す")
	flag.Parse()

	if *healthcheck {
		os.Exit(runHealthcheck())
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("起動できませんでした", "error", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		return errors.New("DATABASE_URL が未設定です")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 起動時の接続確認には別のタイムアウトを使う。
	// ここで ctx をそのまま渡すと、終了シグナル用の ctx と役割が混ざる。
	openCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	st, err := store.Open(openCtx, dsn)
	if err != nil {
		return err
	}
	defer st.Close()

	gen := newGenerator(log)

	srv := &http.Server{
		Addr: net.JoinHostPort("", port()),
		Handler: app.New(app.Config{
			JWTSecret: os.Getenv("SUPABASE_JWT_SECRET"),
			PublicDir: publicDir(),
			DemoMode:  os.Getenv("DEMO_MODE") == "1",
		}, st, gen, log),
		ReadHeaderTimeout: 10 * time.Second,
		// 生成はモデルの応答待ちがあるので書き込み側は長めに取る。
		WriteTimeout: 120 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		log.Info("起動", "addr", srv.Addr, "demo_mode", os.Getenv("DEMO_MODE") == "1")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errCh <- err
		}
	}()

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		// ECS はタスクを止めるとき SIGTERM を送ってから一定時間待つ。
		// 処理中のリクエストを取りこぼさないよう、その間に閉じる。
		log.Info("終了シグナルを受け取ったので、処理中のリクエストを待つ")
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	}
}

// newGenerator は鍵があれば Claude を呼ぶ実装、無ければデモ返信を返す実装を選ぶ。
// 「鍵が無いと動かない」ではなく「鍵が無くても経路は通る」形にしておくと、
// 鍵の無いCIでも認証・上限・応答形式まで通して確かめられる。
func newGenerator(log *slog.Logger) reply.Generator {
	key := os.Getenv("ANTHROPIC_API_KEY")
	if key == "" {
		log.Info("ANTHROPIC_API_KEY が無いためデモ返信を返します")
		return reply.Mock{}
	}
	return reply.NewClaude(os.Getenv("GENERATION_MODEL"))
}

func port() string {
	if p := os.Getenv("PORT"); p != "" {
		return p
	}
	return "8080"
}

func publicDir() string {
	if d := os.Getenv("PUBLIC_DIR"); d != "" {
		return d
	}
	return "public"
}

// runHealthcheck は自分自身の /api/health を叩く。終了コードだけが結果。
func runHealthcheck() int {
	client := &http.Client{Timeout: 3 * time.Second}
	url := fmt.Sprintf("http://127.0.0.1:%s/api/health", port())
	resp, err := client.Get(url)
	if err != nil {
		fmt.Fprintln(os.Stderr, "healthcheck:", err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintln(os.Stderr, "healthcheck: status", resp.StatusCode)
		return 1
	}
	return 0
}
