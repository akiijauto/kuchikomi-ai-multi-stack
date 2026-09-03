# infra — AWS構成（Terraform）

クチコミ返信AIのコンテナを AWS 上で動かすための構成。
**予算 $10未満**という制約から、固定費の大きいものを意図的に外している。

## 構成

```
VPC (10.0.0.0/16)
├─ パブリックサブネット × 2   ... RDSのサブネットグループが2AZ以上を要求するため
├─ Internet Gateway
├─ ECS Fargate (0.25vCPU / 0.5GB)  ... パブリックIPを直付け
├─ RDS PostgreSQL 16 (db.t4g.micro) ... アプリのSGからのみ到達可
├─ ECR                              ... 直近3イメージのみ保持
├─ S3                               ... パブリックアクセス4項目すべて遮断
└─ CloudWatch Logs                  ... 保持3日
```

## 置いていないもの（と、その理由）

| 置かないもの | 理由 | 代わりにどうしたか |
|---|---|---|
| NATゲートウェイ | 月$40前後の固定費 | タスクをパブリックサブネットに置き公開IPを直付け |
| ALB | 月$20前後の固定費 | タスクのIPへ直接アクセス。公開範囲は `allowed_cidr` で絞る |
| Secrets Manager | 1件$0.40/月 | SSMパラメータストア(Standard、無料)のSecureString |
| RDS自動バックアップ | ストレージ課金 | `backup_retention_period = 0`（学習用の割り切り） |
| リモートstate (S3+DynamoDB) | 1人・1台のため不要 | ローカルstate（`.gitignore` 済み） |

**この構成は学習用であり、そのまま本番に使うものではない。**
ALB無し＝TLS終端が無いためHTTPでの通信になる。公開範囲は必ず自分のIPに絞ること。

## 使い方

```bash
cp terraform.tfvars.example terraform.tfvars   # 値を入れる
terraform init
terraform plan
terraform apply
```

### 初回だけ必要なこと（認証）

Terraform を動かすには AWS の認証情報が要る。**このリポジトリには置かない**。

```bash
aws configure          # IAMユーザーのアクセスキーを ~/.aws/credentials に保存
aws sts get-caller-identity   # 自分が誰として繋がっているかを確認
```

アクセスキーは AWS コンソールの `IAM → ユーザー → セキュリティ認証情報` で作る。
**ルートユーザーのキーは作らない**（権限が強すぎ、制限もかけられないため）。

### デプロイはGitHub Actions側で行う

このPCには Docker が無い（WSL2が動かず 2026-09-03 に導入を打ち切った）ため、
イメージのビルドと push はランナー上で行う。apply 後に一度だけ次を設定する:

```bash
terraform output -raw github_deploy_role_arn
gh variable set AWS_DEPLOY_ROLE_ARN --body "<上の出力>"
gh workflow run "Deploy to AWS"
```

長期のアクセスキーを GitHub Secrets に置かず、OIDC でその都度短命トークンを発行させている
（`github_oidc.tf`）。保存する秘密が無いので、漏れる対象そのものが無い。

イメージのビルド〜デプロイ〜状態確認は3つのスクリプトにまとめてある
（`deploy.sh` は**Dockerが動く環境向け**。無い場合は上のワークフローを使う）:

```bash
./deploy.sh   # ビルド → ECRへpush → ECSに再デプロイ → 安定するまで待つ
./status.sh   # 動いているタスクのパブリックIPを調べてヘルスチェック
./logs.sh     # CloudWatch Logs を追う（起動しないときの一次切り分け）
```

ALBを置いていないため**タスクの再起動ごとにIPが変わる**。`status.sh` は
ECS→ENI→EC2 と3つのAPIを辿ってIPを出す（手作業だと毎回面倒なため）。

## 作業が終わったら必ず消す

```bash
terraform destroy
```

RDSは**停止していてもストレージ課金が続く**ため、停止ではなく削除する。
課金を止めつつ構成だけ残したいときは `desired_count = 0` にする手もあるが、
RDSは動いたままなので、確実なのは destroy。

作業後に `Billing → Cost Explorer` で実際の課金額を確認する習慣をつける。

`destroy` のあとに残るもの: ECRのイメージ（`force_delete = true` なので消える）、
CloudWatch Logsのロググループ（`retention_in_days` の分だけ残るが無料枠内）、
そして **OIDCプロバイダとIAMロール**（IAMは無料なので消さずに残してよい。
残しておけば次回 apply したときに GitHub 側の設定を作り直さずに済む）。
