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

# 数値ID。秘密ではなく公開情報で、付け替えもできない。調べ方:
#   gh api repos/<owner>/<repo> --jq '"repo_id=\(.id) owner_id=\(.owner.id)"'
variable "github_owner_id" {
  description = "GitHubの所有者ID（数値）"
  type        = string
  default     = "288162362"
}

variable "github_repository_id" {
  description = "GitHubのリポジトリID（数値）"
  type        = string
  default     = "1352683534"
}

locals {
  github_owner     = split("/", var.github_repository)[0]
  github_repo_name = split("/", var.github_repository)[1]
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    OIDCプロバイダを作るか。1アカウントに1つしか作れないため、
    同じアカウントで既に作ってある場合は false にする。
  EOT
  type        = bool
  default     = true
}

# 拇印を定数で書かない理由（2026-09-03に実際に踏んだ）:
#   ここに DigiCert 時代の拇印をベタ書きしていたところ、GitHubの証明書が
#   Let's Encrypt に変わっていて一致せず、
#   「Not authorized to perform sts:AssumeRoleWithWebIdentity」で全て弾かれた。
#   証明書は更新されるものなので、固定値ではなく実物から取る。
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # チェーン上の証明書すべての拇印を登録する（中間・ルートのどれで検証されても通るように）
  thumbprint_list = data.tls_certificate.github.certificates[*].sha1_fingerprint
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
    #
    # 2026-09-03に踏んだ罠: GitHubの sub の形は1つではない。実測すると
    #   repo:akiijauto@288162362/kuchikomi-ai-multi-stack@1352683534:ref:refs/heads/main
    # のように所有者IDとリポジトリIDが埋め込まれた新形式だった。
    # 旧形式（IDなし）だけを書いていたため一致せず、全て弾かれていた。
    # 数値IDは名前と違って**付け替えができない**ので、こちらの方が本来は厳しい条件になる。
    # 新旧どちらでも通るように両方を許可する（値が複数あるとORで評価される）。
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:*",
        "repo:${local.github_owner}@${var.github_owner_id}/${local.github_repo_name}@${var.github_repository_id}:*",
      ]
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
    resources = [aws_ecr_repository.app.arn, aws_ecr_repository.rails.arn]
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
    resources = [aws_ecs_service.app.id, aws_ecs_service.rails.id]
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
  # AWSへ送る説明文は英数字のみ（日本語はIAM側の検証で弾かれる。2026-09-03実測）
  description = "role for GitHub Actions to push images and redeploy the service"
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
