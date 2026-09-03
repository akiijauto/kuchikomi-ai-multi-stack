// Package store は PostgreSQL(本番は Supabase / RDS)へのアクセスをまとめる。
//
// 表の定義はここでは作らない。正本は web/supabase/schema.sql のままで、
// Go側は既にある表と関数を使うだけにしてある。Next.js版・Rails版と同じ方針。
// 「同じスキーマに別言語の実装を載せる」のがこの演習の主旨なので、
// 定義を3箇所に増やす理由がない。
package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	// ErrProfileNotFound はプロフィール行が見つからないとき。
	ErrProfileNotFound = errors.New("profile not found")
	// ErrLimitExceeded は increment_usage が上限超過で投げた例外(SQLSTATE P0001)。
	ErrLimitExceeded = errors.New("usage limit exceeded")
	// ErrPlanNotFound は上限を決められなかったとき(SQLSTATE P0002)。
	ErrPlanNotFound = errors.New("usage plan not found")
)

// Store はコネクションプールを持つ。
type Store struct {
	pool *pgxpool.Pool
}

// Profile は public.profiles の1行。全列 not null default 付きなので
// NULL を受ける必要がない(schema.sql 側でそう決めてある)。
type Profile struct {
	ID        string
	StoreName string
	Industry  string
	Tone      string
	Signature string
	Plan      string
}

// Open はプールを作り、実際に1本つないで疎通を確かめる。
func Open(ctx context.Context, dsn string) (*Store, error) {
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		return nil, fmt.Errorf("プールを作れませんでした: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("データベースへ接続できませんでした: %w", err)
	}
	return &Store{pool: pool}, nil
}

// Close はプールを閉じる。
func (s *Store) Close() { s.pool.Close() }

// Profile は自分の行だけを読む。
//
// 本番の Supabase では行レベルセキュリティ(RLS)が最後の砦になるが、
// この接続はテーブル所有者のロールなので RLS は素通りする。
// 同じスキーマでも「誰として接続するか」で守りが変わる。
// ここで id を条件に入れているのは飾りではない(Rails版と同じ判断)。
func (s *Store) Profile(ctx context.Context, userID string) (Profile, error) {
	var p Profile
	err := s.pool.QueryRow(ctx,
		`select id::text, store_name, industry, tone, signature, plan
		   from public.profiles where id = $1`, userID,
	).Scan(&p.ID, &p.StoreName, &p.Industry, &p.Tone, &p.Signature, &p.Plan)
	if errors.Is(err, pgx.ErrNoRows) {
		return Profile{}, ErrProfileNotFound
	}
	if err != nil {
		return Profile{}, err
	}
	return p, nil
}

// IncrementUsage は今月の利用回数を1つ増やし、増やした後の値を返す。
//
// 上限の判定を Go 側でやらないのが要点。「今の件数を読む→判定する→書く」に
// 分解すると、同時に2本来たときに上限を超えられる。DB関数は1文の中で
// 判定と加算を行うので、実装言語が何であっても超えない。
// Next.js版・Rails版と同じ関数を呼んでいるため、上限の挙動は自動的に一致する。
func (s *Store) IncrementUsage(ctx context.Context, userID, month string) (int, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // Commit 済みなら no-op

	// increment_usage の中の auth.uid() が読む値を立てる。
	// 第3引数 true は「このトランザクションの中だけ有効」という意味で、
	// プールの接続を使い回しても他のリクエストへ漏れない。
	if _, err := tx.Exec(ctx,
		`select set_config('request.jwt.claim.sub', $1, true)`, userID); err != nil {
		return 0, err
	}

	var count int
	if err := tx.QueryRow(ctx, `select public.increment_usage($1)`, month).Scan(&count); err != nil {
		// メッセージ文字列ではなく SQLSTATE で判定する。
		// 文言で判定すると、DB側の文言を変えた瞬間に静かに壊れる。
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) {
			switch pgErr.Code {
			case "P0001":
				return 0, ErrLimitExceeded
			case "P0002":
				return 0, ErrPlanNotFound
			}
		}
		return 0, err
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return count, nil
}

// EnsureDemoUser はデモ画面用の利用者を用意する。DEMO_MODE のときだけ呼ばれる。
// profiles の行は schema.sql の on_auth_user_created トリガーが作るので、
// ここで作ろうとすると主キー重複になる。作るのではなく更新する。
func (s *Store) EnsureDemoUser(ctx context.Context, userID string, p Profile) error {
	if _, err := s.pool.Exec(ctx,
		`insert into auth.users (id, email) values ($1, $2)
		 on conflict (id) do nothing`, userID, userID+"@example.test"); err != nil {
		return err
	}
	_, err := s.pool.Exec(ctx,
		`update public.profiles
		    set store_name = $2, industry = $3, tone = $4, signature = $5
		  where id = $1`,
		userID, p.StoreName, p.Industry, p.Tone, p.Signature)
	return err
}
