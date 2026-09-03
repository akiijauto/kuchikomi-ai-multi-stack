このディレクトリのSQLは**リポジトリには置かない**（ビルド時に取り込む）。

正本は次の2つで、複製すると定義が2箇所に増えてしまうため:

- `db/init/00_supabase_compat.sql`（リポジトリ直下）
- `web/supabase/schema.sql`

デプロイ用ワークフローが `docker build` の直前にここへコピーする。
`LOAD_SCHEMA=1` で起動すると `bin/docker-entrypoint` が `rails db:bootstrap` を実行する。
