resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-db"
  subnet_ids = aws_subnet.public[*].id
}

# DBパスワードは人が決めない。生成してSSMに置き、アプリはそこから読む。
# URLに入れるため、記号は壊れないものだけに限定する。
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "-_"
}

resource "aws_db_instance" "main" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "kuchikomi"
  username = "postgres"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # --- ここから下はすべて「学習用・費用を抑える」ための設定。実務では変える ---
  backup_retention_period      = 0     # 自動バックアップ無し（ストレージ課金を避ける）
  skip_final_snapshot          = true  # destroy時にスナップショットを作らない
  deletion_protection          = false # 消せる状態にしておく
  performance_insights_enabled = false
  multi_az                     = false
  apply_immediately            = true

  tags = { Name = "${var.name}-db" }
}
