# GitHub Actions から AWS を操作するためのロール。
#
# なぜこれが要るか:
#   ローカルの Docker Desktop が Windows と噛み合わず使えないため、イメージのビルドと
#   ECR への push は GitHub のランナー上で行う（2026-09-03の判断）。つまり CI が
#   AWS を触れる必要がある。
#
# なぜアクセスキーを GitHub Secrets に置かないか:
#   長期キーは「漏れても失効するまで有効」で、漏れたことに気づく手段が無い。
#   OIDC なら GitHub が発行する短命トークン（数分）を AWS が直接検証するので、
#   保存する秘密が存在しない。無料。

variable "github_repository" {
  description = "デプロイを許可するリポジトリ。owner/name 形式"
  type        = string
  default     = "akiijauto/kuchikomi-ai-multi-stack"
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    OIDCプロバイダを作るか。1アカウントに1つしか作れないため、
    同じアカウントで既に作ってある場合は false にする。
  EOT
  type        = bool
  default     = true
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ここを省くと「GitHub上のどのリポジトリからでも」このロールを取れてしまう。
    # 対象リポジトリのワークフローだけに絞る。
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:*"]
    }
  }
}

data "aws_iam_policy_document" "github_deploy" {
  # ECRのログイン用トークン取得だけはリソース指定ができない（AWS側の仕様）
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  # タスク定義は latest を参照している。新しい latest を引かせるには
  # 再デプロイを指示するだけでよく、タスク定義の再登録は不要。
  # 再登録まで許すと iam:PassRole が必要になり、CIの権限が一段強くなる。
  statement {
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [aws_ecs_service.app.id]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecs:ListTasks",
      "ecs:DescribeTasks",
    ]
    resources = ["*"]
    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.main.arn]
    }
  }

  # 起動したタスクの公開IPを引くため（ALBが無い構成なのでIPを自分で調べる）
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeNetworkInterfaces"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.name}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  description        = "GitHub Actions がイメージをpushしECSを再デプロイするためのロール"
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
