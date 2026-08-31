resource "aws_ecr_repository" "app" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"

  # 学習用のため、イメージが残っていても destroy できるようにする。
  # 実務では false のままにして、消す前に必ず中身を確認する。
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 古いイメージを溜めない（ECRは $0.10/GB-月。200MBのイメージが積み上がると効いてくる）
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "直近3イメージだけ残す"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = { type = "expire" }
    }]
  })
}
