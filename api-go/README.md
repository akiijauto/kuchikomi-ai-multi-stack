# api-go — クチコミ返信AI の Go 実装（Week5）

Next.js の API Routes（`web/`）・Ruby on Rails（`api-rails/`）と**同じエンドポイント・
同じスキーマ**を、Go で実装したもの。カリキュラム Week5「1〜2エンドポイントを
net/http または Gin で追加実装」に対応する。

## エンドポイント

| メソッド | パス | 内容 |
|---|---|---|
| GET | `/api/health` | 死活監視。認証基盤にもDBにも依存しない |
| POST | `/api/generate` | 認証・入力検証・上限チェック・返信生成 |
| POST | `/api/demo/token` | デモ用トークン発行。`DEMO_MODE=1` のときだけ**経路が存在する** |

ステータスコードとエラー文言は Next.js版・Rails版に合わせてある（同じ画面から差し替えて呼べる）。

`POST /api/profile` は実装していない。カリキュラムの Week5 は「1〜2エンドポイント」で、
認証・DBアクセス・上限判定・生成をすべて通るのは `/api/generate` のほうだから。

## 構成

```
cmd/api/main.go        起動・設定読み込み・graceful shutdown・-healthcheck
internal/app/          ルーティング / 認証middleware / 入力検証 / 応答
internal/auth/         Supabaseが発行したJWTの検証と、デモ用の発行
internal/store/        PostgreSQLアクセス（pgx）。表の定義は作らない
internal/reply/        返信生成（Claude / APIキーが無いときのデモ返信）
public/demo.html       ブラウザから試せるデモ画面
```

外部依存は3つだけ（`pgx` / `golang-jwt` / `anthropic-sdk-go`）。
ルータのライブラリは入れていない。Go 1.22 以降の `http.ServeMux` が
`"POST /api/generate"` のようなメソッド込みのパターンを扱えるため、この規模では不要。

## 環境変数

| 変数 | 必須 | 既定 | 内容 |
|---|---|---|---|
| `DATABASE_URL` | ✅ | — | `postgresql://user:pass@host:5432/db` |
| `SUPABASE_JWT_SECRET` | ✅ | — | トークンの検証鍵。未設定だと認証つきの口は500を返す |
| `PORT` | | `8080` | 待ち受けポート |
| `PUBLIC_DIR` | | `public` | 静的ファイルの場所 |
| `DEMO_MODE` | | 空 | `1` のときだけデモ用トークンの口が生える |
| `LOAD_SCHEMA` | | 空 | `1` のとき、起動前に `BOOTSTRAP_DIR` の `*.sql` を適用する |
| `BOOTSTRAP_DIR` | | `db/bootstrap` | 適用するSQLの置き場所 |
| `ANTHROPIC_API_KEY` | | 空 | 無ければデモ返信（`mock: true`）を返す |
| `GENERATION_MODEL` | | `claude-sonnet-4-6` | 他の2実装と同じ既定値 |

## 動かす

```bash
export DATABASE_URL=postgresql://postgres:postgres@localhost:5432/kuchikomi
export SUPABASE_JWT_SECRET=dev-secret
export DEMO_MODE=1
go run ./cmd/api
# → http://localhost:8080/demo.html
```

スキーマは `db/init/00_supabase_compat.sql` → `web/supabase/schema.sql` の順に流し込む。
**Go側にマイグレーションは無い。** 表の定義の正本は `web/supabase/schema.sql` のままで、
同じ定義に別言語の実装を載せるのがこの演習の主旨。

AWS上ではRDSに外から接続できない（`publicly_accessible = false`、踏み台もALBも無い）ため、
**スキーマの投入はこのアプリ自身が行う**。`LOAD_SCHEMA=1` で起動すると
`BOOTSTRAP_DIR` の `*.sql` をファイル名順に適用してからサーバーを開く
（`internal/store/bootstrap.go`）。SQLの正本は複製せず、ビルドの直前に
`api-go/db/bootstrap/` へコピーする運用（CI・デプロイのワークフローがやる）。

## テスト

```bash
go test ./...                                   # DBを使わないテストだけ走る
DATABASE_URL=postgresql://... go test ./...     # 全部走る
```

DBを使うテストは `DATABASE_URL` が無ければ **SKIP と表示して飛ばす**。
黙って通したことにはしない（「通った」と「試していない」を取り違えないため）。

## コンテナ

```bash
docker build -t kuchikomi-go .
docker run --rm -p 8080:8080 -e DATABASE_URL=... -e SUPABASE_JWT_SECRET=... kuchikomi-go
```

実行イメージは `gcr.io/distroless/static-debian12:nonroot`。シェルもパッケージマネージャも
入っていないので、`docker exec app id -u` のような確認はできない（`docker inspect` で見る）。
死活監視も `curl` が無いため、バイナリ自身に自分を叩かせている（`/app/api -healthcheck`）。

## AWS へのデプロイ

構成は `infra/ecs_go.tf`（ECR / SSM / タスク定義 / サービス）。
VPC・RDS・ロググループ・IAM実行ロールは Next.js版・Rails版と共用で、
3実装が**同じRDSの同じスキーマ**を見て同時に動く。

```bash
gh workflow run "Deploy to AWS" -f component=go   # ビルド → ECR push → ECS 再デプロイ
./infra/status.sh go                              # 公開IPを調べてヘルスチェック
```

セキュリティグループが開けているのは 3000 番だけなので、タスク定義では `PORT=3000` を渡す
（ローカルとCIでは 8080）。ECSのヘルスチェックはシェルが無いため
`["CMD", "/app/api", "-healthcheck"]` の exec 形式にしてある。
