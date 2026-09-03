output "ecr_repository_url" {
  description = "docker push 先"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster" {
  description = "ECSクラスタ名"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service" {
  description = "ECSサービス名。var.name を変えてもスクリプトが壊れないよう出力する"
  value       = aws_ecs_service.app.name
}

output "assets_bucket" {
  description = "S3バケット名"
  value       = aws_s3_bucket.assets.id
}

output "log_group" {
  description = "CloudWatch Logsのロググループ"
  value       = aws_cloudwatch_log_group.app.name
}

output "db_endpoint" {
  description = "RDSの接続先（VPC内からのみ到達可能）"
  value       = aws_db_instance.main.endpoint
}

output "app_url_hint" {
  description = "アプリのURLの調べ方。ALBが無くタスクごとにIPが変わるため固定値を出せない"
  value       = <<-EOT
    タスクのパブリックIPは起動のたびに変わる。次で調べる:
      aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --query 'taskArns[0]' --output text
      aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks <ARN> \
        --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text
      aws ec2 describe-network-interfaces --network-interface-ids <ENI> \
        --query 'NetworkInterfaces[0].Association.PublicIp' --output text
    → http://<IP>:3000/api/health
  EOT
}

output "github_deploy_role_arn" {
  description = "GitHub Actions の deploy ワークフローに渡すロール。リポジトリ変数 AWS_DEPLOY_ROLE_ARN へ設定する"
  value       = aws_iam_role.github_deploy.arn
}
