resource "aws_s3_bucket" "assets" {
  # バケット名は全世界で一意。prefix にして衝突を避ける
  bucket_prefix = "${var.name}-assets-"

  # 学習用。中身があっても destroy できるようにする
  force_destroy = true
}

# 既定で公開されない状態を明示的に固定する（4項目すべて true）
resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
