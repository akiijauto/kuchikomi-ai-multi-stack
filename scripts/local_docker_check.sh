#!/usr/bin/env bash
# ローカル Docker Desktop での検証を一括で流す（CIで済ませた項目の再現＋ローカルでしか確かめられない開発モード）。
# 使い方: bash scripts/local_docker_check.sh          … 本番相当(runner)＋compose の確認
#         bash scripts/local_docker_check.sh dev      … 上記に加えて開発モード(override.yml)を起動し、ホットリロードを手で確かめる
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== 0. Docker デーモン"
docker info --format 'Server: {{.ServerVersion}} / OS: {{.OperatingSystem}}'

echo "== 1. runner イメージのビルド"
docker build --target runner -t kuchikomi-web:local ./web
docker image inspect kuchikomi-web:local --format 'Size: {{.Size}} bytes'

echo "== 2. 単体起動 → /api/health → 非root"
cid=$(docker run -d --rm -p 3100:3000 kuchikomi-web:local)
trap 'docker stop "$cid" >/dev/null 2>&1 || true' EXIT
for i in $(seq 1 30); do curl -fsS http://localhost:3100/api/health && break || sleep 1; done; echo
echo "uid in container: $(docker exec "$cid" id -u)"
docker stop "$cid" >/dev/null; trap - EXIT

echo "== 3. compose（本番相当のみ。override を重ねない）"
docker compose -f docker-compose.yml up -d --wait
docker compose -f docker-compose.yml ps
curl -fsS http://localhost:3000/api/health; echo
docker compose -f docker-compose.yml exec -T db psql -U postgres -d postgres -c "\dt public.*"
docker compose -f docker-compose.yml down -v

if [ "${1:-}" = "dev" ]; then
  echo "== 4. 開発モード（override.yml が重なる側）。Ctrl+C で終了"
  echo "   別ターミナルで web/src/app/page.tsx を編集し、ブラウザ(http://localhost:3000)が数秒で追従するか確認する"
  docker compose up --build
fi
echo "== 完了"
