# Week5で作った Go API を、Next.js版・Rails版と並べて動かすためのひとそろい。
# 3つの実装が同じRDS・同じスキーマを見て同時に動く形にする。
#
# ネットワーク(VPC/サブネット/SG)・RDS・ロググループ・実行ロールは既存を共用する。
# 増えるのは ECR / SSM / タスク定義 / サービス の4種類だけ。

resource "aws_ecr_repository" "go" {
  name                 = "${var.name}-go"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "go" {
  repository = aws_ecr_repository.go.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep only the latest 3 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}

# 本来は Supabase が持っている署名鍵。ここでは Supabase に繋がない
# デモ構成なので、この環境だけで完結する鍵を生成して使う。
# Rails版とは別の鍵にしてある（片方の鍵で他方のトークンが通らないほうが、
# 「それぞれが独立して検証している」ことがはっきりする）。
resource "random_password" "go_jwt_secret" {
  length  = 48
  special = false
}

locals {
  go_secret_values = {
    SUPABASE_JWT_SECRET = random_password.go_jwt_secret.result
    DATABASE_URL        = local.db_url
  }
}

resource "aws_ssm_parameter" "go" {
  for_each = toset(["SUPABASE_JWT_SECRET", "DATABASE_URL"])

  name  = "/${var.name}/go/${each.value}"
  type  = "SecureString"
  value = local.go_secret_values[each.value]
}

resource "aws_iam_role_policy" "execution_go_secrets" {
  name = "read-go-parameters"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = [for p in aws_ssm_parameter.go : p.arn]
    }]
  })
}

resource "aws_ecs_task_definition" "go" {
  family                   = "${var.name}-go"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # Goの実装はランタイムを持たないぶん常駐メモリが小さい。
  # Rails/Next.js と同じ 256/512 にせず、最小構成(256/512はFargateの下限組)のまま
  # 様子を見る。下げ幅が取れるかは CloudWatch のメモリ使用率で判断する。
  cpu                = 256
  memory             = 512
  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "go"
    image     = "${aws_ecr_repository.go.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      # セキュリティグループが開けているのは3000だけ（network.tf）。
      # 3実装とも同じ口にしておくと、確認手順が実装ごとに分かれない。
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "PORT", value = "3000" },
      # RDSは外部から接続できないため、コンテナ自身にスキーマを流させる
      { name = "LOAD_SCHEMA", value = "1" },
      # デモ用トークン発行の口。学習用の公開範囲(自分のIPのみ)を前提にした設定で、
      # 実運用では絶対に有効にしない
      { name = "DEMO_MODE", value = var.go_demo_mode ? "1" : "0" },
    ]

    secrets = [
      for k, p in aws_ssm_parameter.go : {
        name      = k
        valueFrom = p.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "go"
      }
    }

    # 実行イメージ(distroless)にはシェルもcurlも無いので CMD-SHELL は使えない。
    # バイナリ自身に自分を叩かせる（PORT を読んで /api/health を見る）。
    healthCheck = {
      command     = ["CMD", "/app/api", "-healthcheck"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])
}

resource "aws_ecs_service" "go" {
  name            = "${var.name}-go"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.go.arn
  desired_count   = var.go_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  depends_on = [aws_iam_role_policy_attachment.execution_managed]
}
