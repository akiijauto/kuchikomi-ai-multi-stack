package app

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/auth"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/reply"
	"github.com/akiijauto/kuchikomi-ai-multi-stack/api-go/internal/store"
	"github.com/jackc/pgx/v5/pgxpool"
)

// このファイルのテストは本物の PostgreSQL を使う。
// Next.js版・Rails版と同じ 00_supabase_compat.sql ＋ schema.sql を流し込んだDBに対して
// 実行することで、「同じ定義に対して3つ目の実装が通る」ことを確かめている。
//
// DATABASE_URL が無い環境（ローカルにPostgreSQLを入れていない）では飛ばす。
// 飛ばしたことがログに出るので、「通った」と「試していない」を取り違えない。
const testSecret = "test-secret-for-go-tests-only-not-a-real-key"

type testEnv struct {
	server *httptest.Server
	pool   *pgxpool.Pool
}

func newTestEnv(t *testing.T) *testEnv {
	t.Helper()

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL が未設定のため、DBを使うテストは実行しない")
	}

	ctx := context.Background()
	st, err := store.Open(ctx, dsn)
	if err != nil {
		t.Fatalf("DBへ接続できない: %v", err)
	}
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("テスト用のプールを作れない: %v", err)
	}

	srv := httptest.NewServer(New(Config{
		JWTSecret: testSecret,
		DemoMode:  true,
	}, st, reply.Mock{}, slog.New(slog.NewTextHandler(io.Discard, nil))))

	t.Cleanup(func() {
		srv.Close()
		pool.Close()
		st.Close()
	})
	return &testEnv{server: srv, pool: pool}
}

type profileOption func(*store.Profile)

func withPlan(plan string) profileOption   { return func(p *store.Profile) { p.Plan = plan } }
func withStoreName(n string) profileOption { return func(p *store.Profile) { p.StoreName = n } }
func withSignature(s string) profileOption { return func(p *store.Profile) { p.Signature = s } }

// createUser は利用者を1人作り、そのIDを返す。
// profiles の行は schema.sql の on_auth_user_created トリガーが作るので、
// ここで insert すると主キー重複になる。作るのではなく更新する
// （Rails版のテストヘルパで実際に踏んだ落とし穴）。
func (e *testEnv) createUser(t *testing.T, opts ...profileOption) string {
	t.Helper()
	ctx := context.Background()

	p := store.Profile{StoreName: "テスト店", Industry: "飲食店", Tone: "polite", Plan: "free"}
	for _, opt := range opts {
		opt(&p)
	}

	var id string
	if err := e.pool.QueryRow(ctx,
		`insert into auth.users (email) values (gen_random_uuid()::text || '@example.test')
		 returning id::text`).Scan(&id); err != nil {
		t.Fatalf("利用者を作れない: %v", err)
	}
	if _, err := e.pool.Exec(ctx,
		`update public.profiles
		    set store_name=$2, industry=$3, tone=$4, signature=$5, plan=$6
		  where id=$1`,
		id, p.StoreName, p.Industry, p.Tone, p.Signature, p.Plan); err != nil {
		t.Fatalf("プロフィールを更新できない: %v", err)
	}
	return id
}

func (e *testEnv) usageCount(t *testing.T, userID string) int {
	t.Helper()
	var count int
	err := e.pool.QueryRow(context.Background(),
		`select coalesce(sum(count), 0)::int from public.usage_logs where user_id = $1`,
		userID).Scan(&count)
	if err != nil {
		t.Fatalf("利用回数を読めない: %v", err)
	}
	return count
}

// generate は /api/generate を叩く。token が空なら Authorization を付けない。
func (e *testEnv) generate(t *testing.T, token, body string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(http.MethodPost, e.server.URL+"/api/generate", strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := e.server.Client().Do(req)
	if err != nil {
		t.Fatalf("リクエストに失敗: %v", err)
	}
	return resp
}

func (e *testEnv) generateAs(t *testing.T, userID, body string) *http.Response {
	t.Helper()
	token, err := auth.Issue(userID, testSecret, time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	return e.generate(t, token, body)
}

func decode[T any](t *testing.T, resp *http.Response) T {
	t.Helper()
	defer resp.Body.Close()
	var out T
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("応答を読めない: %v", err)
	}
	return out
}

const validBody = `{"review":{"reviewText":"スープが本当に美味しかったです","rating":5}}`

func TestHealth(t *testing.T) {
	e := newTestEnv(t)
	resp, err := e.server.Client().Get(e.server.URL + "/api/health")
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	body := decode[map[string]any](t, resp)
	if body["status"] != "ok" {
		t.Fatalf("body=%v", body)
	}
}

func TestGenerateRejectsBadTokens(t *testing.T) {
	e := newTestEnv(t)
	userID := e.createUser(t)

	otherKey, _ := auth.Issue(userID, "another-secret", time.Hour)
	expired, _ := auth.Issue(userID, testSecret, -time.Minute)

	tests := map[string]string{
		"トークンが無い":      "",
		"別の鍵で署名":       otherKey,
		"期限切れ":         expired,
		"トークンとして壊れている": "not.a.token",
	}
	for name, token := range tests {
		t.Run(name, func(t *testing.T) {
			resp := e.generate(t, token, validBody)
			defer resp.Body.Close()
			if resp.StatusCode != http.StatusUnauthorized {
				t.Fatalf("status=%d。期待は401", resp.StatusCode)
			}
		})
	}
}

func TestGenerateValidation(t *testing.T) {
	e := newTestEnv(t)

	t.Run("JSONとして壊れている", func(t *testing.T) {
		userID := e.createUser(t)
		resp := e.generateAs(t, userID, `{"review":`)
		body := decode[map[string]string](t, resp)
		if resp.StatusCode != http.StatusBadRequest || body["error"] != "不正なリクエストです" {
			t.Fatalf("status=%d body=%v", resp.StatusCode, body)
		}
	})

	t.Run("口コミが短すぎる", func(t *testing.T) {
		userID := e.createUser(t)
		resp := e.generateAs(t, userID, `{"review":{"reviewText":"美味","rating":5}}`)
		body := decode[map[string]string](t, resp)
		if resp.StatusCode != http.StatusBadRequest || body["error"] != "入力内容を確認してください" {
			t.Fatalf("status=%d body=%v", resp.StatusCode, body)
		}
		if n := e.usageCount(t, userID); n != 0 {
			t.Fatalf("弾いたのに利用回数が %d 増えている", n)
		}
	})

	t.Run("星の値が範囲外", func(t *testing.T) {
		userID := e.createUser(t)
		resp := e.generateAs(t, userID, `{"review":{"reviewText":"とても良かったです","rating":9}}`)
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("status=%d", resp.StatusCode)
		}
	})

	t.Run("店名が未設定", func(t *testing.T) {
		userID := e.createUser(t, withStoreName(""))
		resp := e.generateAs(t, userID, validBody)
		body := decode[map[string]string](t, resp)
		if resp.StatusCode != http.StatusBadRequest || !strings.Contains(body["error"], "プロフィール") {
			t.Fatalf("status=%d body=%v", resp.StatusCode, body)
		}
	})
}

func TestGenerateSuccess(t *testing.T) {
	e := newTestEnv(t)
	userID := e.createUser(t, withSignature("店主 太郎"))

	resp := e.generateAs(t, userID, validBody)
	if resp.StatusCode != http.StatusOK {
		defer resp.Body.Close()
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("status=%d body=%s", resp.StatusCode, raw)
	}
	got := decode[generateResponse](t, resp)

	if !got.Mock {
		t.Error("APIキーが無いのに mock=false")
	}
	if len(got.Replies) != 3 {
		t.Fatalf("返信案が %d 件。期待は3件", len(got.Replies))
	}
	if !strings.Contains(got.Replies[0].Text, "店主 太郎") {
		t.Error("署名が付いていない")
	}
	if got.Usage != (usageBody{Used: 1, Limit: 5}) {
		t.Errorf("usage=%+v。期待は used=1 limit=5", got.Usage)
	}
}

func TestFreePlanLimit(t *testing.T) {
	e := newTestEnv(t)
	userID := e.createUser(t, withPlan("free"))
	other := e.createUser(t, withPlan("free"))

	for i := 1; i <= 5; i++ {
		resp := e.generateAs(t, userID, validBody)
		got := decode[generateResponse](t, resp)
		if resp.StatusCode != http.StatusOK || got.Usage.Used != i {
			t.Fatalf("%d回目: status=%d usage=%+v", i, resp.StatusCode, got.Usage)
		}
	}

	resp := e.generateAs(t, userID, validBody)
	body := decode[map[string]string](t, resp)
	if resp.StatusCode != http.StatusTooManyRequests {
		t.Fatalf("6回目の status=%d。期待は429", resp.StatusCode)
	}
	if !strings.Contains(body["error"], "上限に達しました") {
		t.Errorf("文言が違う: %v", body)
	}
	// 上限に達した回の分が加算されていないこと（DB関数側の保証を実際に確かめる）
	if n := e.usageCount(t, userID); n != 5 {
		t.Fatalf("利用回数が %d。5で止まっているべき", n)
	}
	// 他人の回数に影響していないこと
	if n := e.usageCount(t, other); n != 0 {
		t.Fatalf("他人の利用回数が %d になっている", n)
	}
}

// TestConcurrentGenerateStopsAtLimit は「上限判定をアプリ側に持ってこなかった」
// 設計判断が実際に効いていることを確かめる。
//
// 同時に10本投げても、成功はちょうど5本でなければならない。
// アプリ側で「今の件数を読む→判定する→書く」に分けていたら、
// 読んだ後・書く前に他のリクエストが割り込めるので、ここで6本以上通る。
// DB関数は判定と加算を1文で行うため、実装言語が何であっても超えない。
func TestConcurrentGenerateStopsAtLimit(t *testing.T) {
	e := newTestEnv(t)
	userID := e.createUser(t, withPlan("free"))

	const parallel = 10
	codes := make(chan int, parallel)
	var wg sync.WaitGroup
	for range parallel {
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp := e.generateAs(t, userID, validBody)
			resp.Body.Close()
			codes <- resp.StatusCode
		}()
	}
	wg.Wait()
	close(codes)

	ok, tooMany, other := 0, 0, 0
	for code := range codes {
		switch code {
		case http.StatusOK:
			ok++
		case http.StatusTooManyRequests:
			tooMany++
		default:
			other++
		}
	}
	if ok != 5 || tooMany != 5 || other != 0 {
		t.Fatalf("成功=%d 429=%d その他=%d。期待は 5 / 5 / 0", ok, tooMany, other)
	}
	if n := e.usageCount(t, userID); n != 5 {
		t.Fatalf("利用回数が %d。5で止まっているべき", n)
	}
}

func TestProPlanExceedsFreeLimit(t *testing.T) {
	e := newTestEnv(t)
	userID := e.createUser(t, withPlan("pro"))

	for i := 1; i <= 6; i++ {
		resp := e.generateAs(t, userID, validBody)
		got := decode[generateResponse](t, resp)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("%d回目で status=%d", i, resp.StatusCode)
		}
		if got.Usage.Limit != 300 {
			t.Fatalf("limit=%d。期待は300", got.Usage.Limit)
		}
	}
	if n := e.usageCount(t, userID); n != 6 {
		t.Fatalf("利用回数が %d。6であるべき", n)
	}
}

func TestDemoTokenFlow(t *testing.T) {
	e := newTestEnv(t)

	resp, err := e.server.Client().Post(e.server.URL+"/api/demo/token", "application/json", nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status=%d", resp.StatusCode)
	}
	issued := decode[struct {
		Token string `json:"token"`
	}](t, resp)
	if issued.Token == "" {
		t.Fatal("トークンが空")
	}

	got := decode[generateResponse](t, e.generate(t, issued.Token, validBody))
	if len(got.Replies) != 3 {
		t.Fatalf("返信案が %d 件", len(got.Replies))
	}
}

func TestDemoRouteAbsentWhenDisabled(t *testing.T) {
	// DEMO_MODE が無効なら、経路そのものが存在しないこと。
	// ハンドラ内で弾く作りだと、設定を間違えたときに口が開いたままになる。
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL が未設定のため実行しない")
	}
	srv := httptest.NewServer(New(Config{JWTSecret: testSecret, DemoMode: false},
		nil, reply.Mock{}, slog.New(slog.NewTextHandler(io.Discard, nil))))
	defer srv.Close()

	resp, err := srv.Client().Post(srv.URL+"/api/demo/token", "application/json", bytes.NewReader(nil))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("status=%d。期待は404", resp.StatusCode)
	}
}
