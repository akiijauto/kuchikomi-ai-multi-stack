このディレクトリのSQLは**リポジトリには置かない**（ビルド時に取り込む）。

正本は次の2つで、複製すると定義が3箇所に増えてしまうため:

- `db/init/00_supabase_compat.sql`（リポジトリ直下）
- `web/supabase/schema.sql`

CI とデプロイ用ワークフローが `docker build` の直前にここへコピーする。
`LOAD_SCHEMA=1` で起動すると、アプリ自身が起動前にこのディレクトリの
`*.sql` をファイル名順で適用する（`internal/store/bootstrap.go`）。

RDSは `publicly_accessible = false` で手元から psql を流せず、
ロードバランサも踏み台も置いていないため、VPC内にいるアプリのタスクに流させている。
