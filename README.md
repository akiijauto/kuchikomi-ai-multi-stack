# kuchikomi-ai-multi-stack

稼働中の個人開発サービス **クチコミ返信AI**（Next.js / Vercel / Supabase / Stripe）を、
求人票に頻出する技術スタックで作り替えていく学習用リポジトリ。

目的は「1つのサービスを複数スタックで作り替える」ことで、Docker / AWS / CI-CD / Rails / Go
それぞれに**実際に手を動かした実績**を作ること。本番サービスのリポジトリ
（`kuchikomi-ai`）とは分離してあり、ここでの変更が本番へ影響することはない。

## 進捗

| Week | 技術 | 状態 |
|---|---|---|
| 1 | Docker | 完了。本番相当・開発モード（ホットリロード）ともCI上で実地検証済み |
| 2 | AWS | 完了。apply → デプロイ → 動作確認 → destroy を2周し、残存ゼロを実測 |
| 3 | CI/CD (GitHub Actions) | 完了。CI 9ジョブ＋ OIDC による AWS 自動デプロイ |
| 4 | Ruby on Rails | 完了。既存APIを再実装し、コンテナ化してAWSで稼働・デモ画面まで確認 |
| 5 | Go | 完了。`api-go/` を実装しCIへ組み込み、AWSでNext.js版・Rails版と**3実装同時稼働**まで確認して destroy 済み |
| 6 | 棚卸し | 完了。3実装の比較と学習記録をまとめ、スキルシートへ反映 |

## 同じAPIを3言語で書いて分かったこと

`api-rails/` と `api-go/` は、`web/`（Next.js）で動いている **`/api/health` と `/api/generate`**
を作り替えたもの。**全機能を移植したわけではない**（決済・下書き生成などは Next.js 側にしか無い）。
比較のために作った表ではなく、**3つ同時にAWSで動かして**確かめた結果である。

| | Next.js (TypeScript) | Rails (Ruby) | Go |
|---|---|---|---|
| 本体 | 119行（該当ルート2本） | 434行（`app/`配下） | 999行 |
| テスト | — | 279行（RSpec） | 680行 |
| ルーティング | ファイル配置 | `routes.rb` | `net/http` の `ServeMux` のみ（ライブラリ不使用） |
| 認証 | Supabase クライアント | 自前（JWT gem） | 自前（golang-jwt v5） |
| DB | Supabase クライアント | ActiveRecord + 生SQL | pgx v5（接続プールも明示） |
| 実行イメージ | node:slim | ruby:slim | **distroless**（シェルなし） |

**この行数の差は「Goが冗長」という意味ではない。肩代わりしてくれる量の差である。**
Next.js の119行が短いのは、認証・DB接続・ルーティングを Supabase と Next が持っているから。
Go の999行には、**その肩代わりの中身が全部入っている** — ルーティング、接続プール、JWT検証、
リクエストのログ、graceful shutdown、JSONのパース失敗と型不一致の区別。

分かったのは「どちらが良いか」ではなく、**フレームワークが何をやってくれていたのかが、
自分で書いて初めて分かる**ということだった。Next.js版を書いていたときは、
JWTの署名方式を検証する必要があることすら意識していなかった（下記）。

### 3実装で挙動を揃えるためにやったこと

素直に書くと、**同じ仕様のつもりで3つの実装がずれる**。特に利用回数の上限判定は、
3実装がそれぞれ「数えて、比べて、記録する」を実装すると、
同時に叩かれたときに**それぞれが別々に数えてしまう**。

そこで**上限判定をアプリから外し、PostgreSQL の関数に1つだけ置いた**
（`db/init/01_schema.sql` の `increment_usage`、`SECURITY DEFINER`）。
3実装はいずれもこの関数を呼ぶだけで、判定ロジックを持たない。

- 加算と上限の比較が**1つの `insert ... on conflict ... do update ... where count < 上限`**
  の中で行われるので、同時に来ても上限を超えて通らない（アプリ側で読んでから書くと隙間ができる）
- 上限超過は例外（SQLSTATE `P0001`）で返り、3実装とも**それを 429 に翻訳するだけ**
- 認証情報は `set_config('request.jwt.claim.sub', $1, true)` で**トランザクションの中だけ**に立てる

**AWS上で3実装を同時に立ち上げ、Next.js版で上限まで使ってから Go版・Rails版を叩いて、
両方とも 429 が返ることを実測した。** 実装をまたいで1つのカウンタが効いている証明になる。

### 各言語で実際に踏んだもの

学習の中身はここに出るので、記録として残す。

**Go**
- `go get` は通ったのに `go build` が `missing go.sum entry` で落ちた。
  **「依存を足した」と「ビルドに必要なものが揃った」は別**で、`go mod tidy` が要る
- `gofmt -l .` が全ファイルを差分として出した。原因は書式ではなく**改行コード**で、
  `.gitattributes` が親ディレクトリにしか無く、切り出したリポジトリでは効いていなかった
- 日本語の入力文字数を `len()` で数えると**3倍に数える**（UTF-8のバイト数のため）。
  `utf8.RuneCountInString` に変更
- JWT の検証で**アルゴリズムを指定しない**と、署名方式をすり替えられる余地が残る。
  `jwt.WithValidMethods([]string{"HS256"})` を明示
- distroless にはシェルも curl も無いので、`HEALTHCHECK` に書けるコマンドが無い。
  **バイナリ自身に `-healthcheck` フラグを付けて、自分で自分を叩く**形にした

**AWS / CI**
- リポジトリを作り直したら OIDC のデプロイが落ちた。
  新形式の `sub` には**リポジトリの数値IDが入る**ため、作り直すと一致しなくなる
- IAMの許可対象に Go のリポジトリを足し忘れ、**ビルドが全部成功したあと最後の push だけ**落ちた。
  権限の失敗は最後に出るので、途中の成功をあてにしない

## 実測した結果

- **apply → 3実装同時稼働 → 動作確認 → destroy** を通し、`terraform state list` が空、
  AWSコンソール側も残存ゼロを確認（Week2・Week5 の計3周）
- Terraform **46リソース**（ECR / ECS Fargate / RDS / ALB / SSM / IAM / OIDC）
- CI **10ジョブ**（`ci.yml`）＋ OIDC 経由の自動デプロイ（`deploy.yml`）

## 構成

```
web/                    Next.js 16 アプリ（本番リポジトリの web/ を git ls-files 起点で複製）
  Dockerfile            deps → builder → runner / dev の4ステージ
  .dockerignore
api-rails/              Ruby on Rails 実装（Week4）
api-go/                 Go 実装（Week5）。net/http のみ、ルータのライブラリは使わない
db/init/                ローカルPostgresの初期化SQL
  00_supabase_compat.sql  素のPostgresでSupabase前提のスキーマを流すための互換シム
  01_schema.sql           web/supabase/schema.sql の複製
infra/                  AWS構成（Terraform）＋デプロイ用スクリプト
docker-compose.yml          ベース＝本番相当（runner ステージ）
docker-compose.override.yml 開発用の上書き（dev ステージ＋ホットリロード）
docs/学習記録.md            何をやって何が分かったかの記録
```

## 使い方

### 前提

- Docker Desktop（Compose v2.24 以降。`env_file` の `required: false` 記法を使用）

### 環境変数

```bash
cp .env.example .env          # NEXT_PUBLIC_*（ビルド時に埋め込まれる公開値）
cp web/.env.example web/.env  # サーバー側の鍵（ANTHROPIC_API_KEY / STRIPE_* など）
```

`web/.env` が無くても起動はする（AIキー未設定時はモックモードで動作する設計）。

### 開発モード（ホットリロード）

```bash
docker compose up --build
```

http://localhost:3000 。`web/` を編集すると即反映される。

### 本番相当モード（standalone ビルドの実行イメージ）

```bash
docker compose -f docker-compose.yml up --build
```

### ローカルDBの確認

```bash
docker compose exec db psql -U postgres -d kuchikomi -c '\dt public.*'
```

スキーマを作り直すときは `docker compose down -v`（初期化SQLは初回起動時のみ実行されるため）。

### ヘルスチェック

`GET /api/health` → `{"status":"ok"}`。認証基盤に依存させないため `src/proxy.ts` の
matcher から除外している。Docker の HEALTHCHECK と、Week2 の ALB/ECS ヘルスチェックで使う。

## 本番リポジトリとの関係

`web/` は本番リポジトリ `kuchikomi-ai` の `web/` を複製したもの。本番へ取り込みたい変更が
出た場合のみ、個別に反映する（自動同期はしない）。
