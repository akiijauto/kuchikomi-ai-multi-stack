# Week4で作った Rails API を、Next.js版と並べて動かすためのひとそろい。
# 「Next.jsフロント＋RailsバックエンドAPI」は実務でよくある構成で、
# Rails習得カリキュラム側でも Week4〜5 の題材として挙げられている。

resource "aws_ecr_repository" "rails" {
  name                 = "${var.name}-rails"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "rails" {
  repository = aws_ecr_repository.rails.name

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

# Railsが必要とする秘密値。人が決めず生成し、SSMへ置く。
# SECRET_KEY_BASE を渡すことで、イメージに config/master.key を含めずに済む
# （master.key をイメージへ焼くと、イメージを取れる人が全部読めてしまう）。
resource "random_password" "rails_secret_key_base" {
  length  = 64
  special = false
}

# 本来は Supabase が持っている署名鍵。ここでは Supabase に繋がない
# デモ構成なので、この環境だけで完結する鍵を生成して使う。
resource "random_password" "rails_jwt_secret" {
  length  = 48
  special = false
}

locals {
  rails_secret_values = {
    SECRET_KEY_BASE     = random_password.rails_secret_key_base.result
    SUPABASE_JWT_SECRET = random_password.rails_jwt_secret.result
    DATABASE_URL        = local.db_url
  }
}

resource "aws_ssm_parameter" "rails" {
  for_each = toset(["SECRET_KEY_BASE", "SUPABASE_JWT_SECRET", "DATABASE_URL"])

  name  = "/${var.name}/rails/${each.value}"
  type  = "SecureString"
  value = local.rails_secret_values[each.value]
}

resource "aws_iam_role_policy" "execution_rails_secrets" {
  name = "read-rails-parameters"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters"]
      Resource = [for p in aws_ssm_parameter.rails : p.arn]
    }]
  })
}

resource "aws_ecs_task_definition" "rails" {
  family                   = "${var.name}-rails"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "rails"
    image     = "${aws_ecr_repository.rails.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      containerPort = 3000
      protocol      = "tcp"
    }]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      # この構成にはTLS終端が無い（$10予算のためロードバランサを置いていない）。
      # 既定のままだとRailsが全リクエストをhttpsへ転送して繋がらない。
      { name = "RAILS_FORCE_SSL", value = "false" },
      # Thrusterが待ち受ける口を3000に、その先のRailsを3001にずらす
      { name = "HTTP_PORT", value = "3000" },
      { name = "TARGET_PORT", value = "3001" },
      # RDSは外部から接続できないため、コンテナ自身にスキーマを流させる
      { name = "LOAD_SCHEMA", value = "1" },
      # デモ用トークン発行の口。学習用の公開範囲(自分のIPのみ)を前提にした設定で、
      # 実運用では絶対に有効にしない
      { name = "DEMO_MODE", value = var.rails_demo_mode ? "1" : "0" },
    ]

    secrets = [
      for k, p in aws_ssm_parameter.rails : {
        name      = k
        valueFrom = p.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "rails"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -fsS http://127.0.0.1:3000/api/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "rails" {
  name            = "${var.name}-rails"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.rails.arn
  desired_count   = var.rails_desired_count
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
