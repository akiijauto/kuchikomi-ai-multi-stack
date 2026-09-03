terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # GitHubのOIDC証明書の拇印を実物から取るために使う（固定値を書かないため）
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # 学習用のため state はローカル。実務では S3 + DynamoDB のリモートstateにする
  # （複数人・複数マシンで壊さないため）。ここでは1人・1台なので省略している。
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "kuchikomi-ai-multi-stack"
      ManagedBy = "terraform"
      Purpose   = "learning"
    }
  }
}
