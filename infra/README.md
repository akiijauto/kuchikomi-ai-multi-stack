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

イメージを ECR へ push:

```bash
ECR=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin "${ECR%%/*}"
docker build -t "$ECR:latest" ../web
docker push "$ECR:latest"
aws ecs update-service --cluster $(terraform output -raw ecs_cluster) --service kuchikomi --force-new-deployment
```

## 作業が終わったら必ず消す

```bash
terraform destroy
```

RDSは**停止していてもストレージ課金が続く**ため、停止ではなく削除する。
課金を止めつつ構成だけ残したいときは `desired_count = 0` にする手もあるが、
RDSは動いたままなので、確実なのは destroy。

作業後に `Billing → Cost Explorer` で実際の課金額を確認する習慣をつける。
