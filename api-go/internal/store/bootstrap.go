package store

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// LoadSchema は指定ディレクトリの *.sql をファイル名順に実行する。
//
// なぜアプリがスキーマを流すのか:
// 表の定義の正本は web/supabase/schema.sql（Next.js版・Rails版と共有）で、
// Go側にマイグレーションは持たない。そしてRDSは publicly_accessible = false のため
// 手元から psql で流せない。ロードバランサも踏み台も置いていないので、
// VPC内にいるのはアプリのタスクだけ。そのタスクに流させるのが一番素直だった
// （Rails版の db:bootstrap と同じ考え方）。
//
// 冪等性: schema.sql は create table if not exists / create or replace で書かれており、
// 何度実行しても同じ結果になる。起動のたびに走っても問題ない。
//
// pgx は「引数が無いときは必ず simple protocol を使う」ため、
// 1ファイルに複数の文が入っていてもそのまま実行できる（conn.go の exec を参照）。
func (s *Store) LoadSchema(ctx context.Context, dir string) error {
	files, err := filepath.Glob(filepath.Join(dir, "*.sql"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		// 黙って成功にしない。「流したつもり」で起動すると、
		// 後続の失敗が「DBがおかしい」に見えてしまう。
		return fmt.Errorf("%s にSQLが無い。イメージのビルド時に取り込めていない可能性がある", dir)
	}
	sort.Strings(files)

	for _, path := range files {
		sqlText, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("%s を読めない: %w", path, err)
		}
		if _, err := s.pool.Exec(ctx, string(sqlText)); err != nil {
			return fmt.Errorf("%s の適用に失敗: %w", filepath.Base(path), err)
		}
	}
	return nil
}

// SchemaFiles は適用対象のファイル名を返す（ログ用）。
func SchemaFiles(dir string) []string {
	files, _ := filepath.Glob(filepath.Join(dir, "*.sql"))
	sort.Strings(files)
	names := make([]string, len(files))
	for i, f := range files {
		names[i] = filepath.Base(f)
	}
	return names
}
