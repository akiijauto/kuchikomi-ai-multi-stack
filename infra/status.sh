#!/usr/bin/env bash
# 動いているタスクのパブリックIPを調べてヘルスチェックまで行う。
#
# ALBを置いていないのでタスクの再起動ごとにIPが変わる。
# 毎回3つのAPIを辿る必要があり手作業だと面倒なので、まとめてある。
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER=$(terraform output -raw ecs_cluster)

TASK=$(aws ecs list-tasks --cluster "$CLUSTER" --desired-status RUNNING \
        --query 'taskArns[0]' --output text)
if [ "$TASK" = "None" ] || [ -z "$TASK" ]; then
  echo "動いているタスクがありません（desired_count が 0、または起動途中）"
  exit 1
fi

ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK" \
       --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
       --output text)

IP=$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" \
      --query 'NetworkInterfaces[0].Association.PublicIp' --output text)

echo "タスク : $TASK"
echo "URL    : http://$IP:3000"
echo
echo "==> ヘルスチェック"
curl -fsS --max-time 10 "http://$IP:3000/api/health" && echo
