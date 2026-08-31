#!/usr/bin/env bash
# CloudWatch Logs の直近ログを追う。コンテナが起動しないときの一次切り分け用。
set -euo pipefail
cd "$(dirname "$0")"
aws logs tail "$(terraform output -raw log_group)" --follow --since 10m
