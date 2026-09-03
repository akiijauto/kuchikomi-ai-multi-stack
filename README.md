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
| 5 | Go | 実装・テスト・CI 完了（`api-go/`）。AWS構成（`infra/ecs_go.tf`）も実装済みで validate 通過。**apply は未実行** |
| 6 | 棚卸し | 未着手 |

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
