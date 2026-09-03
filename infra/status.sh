#!/usr/bin/env bash
# 動いているタスクのパブリックIPを調べてヘルスチェックまで行う。
#
# ALBを置いていないのでタスクの再起動ごとにIPが変わる。
# 毎回3つのAPIを辿る必要があり手作業だと面倒なので、まとめてある。
#
# 使い方:
#   ./status.sh          3実装（web / rails / go）をまとめて見る
#   ./status.sh go       1つだけ見る
#
# サービスを指定できるようにしたのは Week5 から。
# 同じクラスタに3つのサービスが並ぶので、
# 「クラスタの最初のタスク」を見る書き方だとどの実装を見ているのか分からなくなる。
set -uo pipefail
cd "$(dirname "$0")"

CLUSTER=$(terraform output -raw ecs_cluster)
BASE=$(terraform output -raw ecs_service) # web のサービス名がそのまま接頭辞
if [ -z "$CLUSTER" ] || [ -z "$BASE" ]; then
  echo "terraform output が空。apply 前か、別のディレクトリで実行している" >&2
  exit 1
fi

service_name() {
  case "$1" in
  web) echo "$BASE" ;;
  *) echo "${BASE}-$1" ;;
  esac
}

check() {
  local component="$1"
  local service
  service=$(service_name "$component")
  echo "==> $component（service: $service）"

  local task eni ip
  task=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$service" \
    --desired-status RUNNING --query 'taskArns[0]' --output text 2>/dev/null)
  if [ -z "$task" ] || [ "$task" = "None" ]; then
    echo "   動いているタスクがありません（desired_count が 0、起動途中、または未作成）"
    echo
    return 1
  fi

  eni=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$task" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)
  ip=$(aws ec2 describe-network-interfaces --network-interface-ids "$eni" \
    --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

  echo "   URL   : http://$ip:3000"
  # デモ画面を持つのは Rails版とGo版だけ（web は本番と同じ画面がトップにある）
  if [ "$component" != "web" ]; then
    echo "   デモ  : http://$ip:3000/demo.html"
  fi
  printf '   health: '
  if curl -fsS --max-time 10 "http://$ip:3000/api/health"; then
    echo
  else
    echo "応答なし（allowed_cidr が自分のIPを許しているか確認）"
    echo
    return 1
  fi
  echo
}

failed=0
if [ $# -gt 0 ]; then
  check "$1" || failed=1
else
  for c in web rails go; do
    check "$c" || failed=1
  done
fi

exit "$failed"
