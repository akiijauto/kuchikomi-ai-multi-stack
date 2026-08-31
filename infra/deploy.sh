#!/usr/bin/env bash
# イメージをビルドしてECRへpushし、ECSに新しいタスクを起動させる。
#
# 前提: terraform apply 済み / docker が動く / aws CLI が認証済み
# 使い方: ./deploy.sh
set -euo pipefail
cd "$(dirname "$0")"

command -v docker    >/dev/null || { echo "docker が見つかりません"; exit 1; }
command -v aws       >/dev/null || { echo "aws CLI が見つかりません"; exit 1; }
command -v terraform >/dev/null || { echo "terraform が見つかりません"; exit 1; }

# terraform の出力から接続先を取る（値をスクリプトに埋め込まない）
ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER=$(terraform output -raw ecs_cluster)
SERVICE=$(terraform output -raw ecs_service)
REGISTRY="${ECR_URL%%/*}"
REGION=$(terraform output -raw ecr_repository_url | cut -d. -f4)

# コミットハッシュをタグにする。latest だけだと「今動いているのがどのコードか」が追えない
TAG=$(git rev-parse --short HEAD)

echo "==> ECRへログイン ($REGISTRY)"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> ビルド ($TAG)"
# NEXT_PUBLIC_* はビルド時に焼き込まれる。terraform.tfvars と同じ値を渡す必要がある
docker build \
  --target runner \
  --build-arg NEXT_PUBLIC_SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-http://localhost:54321}" \
  --build-arg NEXT_PUBLIC_SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-dummy-anon-key-for-build}" \
  -t "$ECR_URL:$TAG" -t "$ECR_URL:latest" \
  ../web

echo "==> push"
docker push "$ECR_URL:$TAG"
docker push "$ECR_URL:latest"

echo "==> ECSに再デプロイさせる"
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  --no-cli-pager >/dev/null

echo "==> 新しいタスクが安定するまで待つ（数分かかる）"
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

echo "完了。接続先の確認は ./status.sh"
