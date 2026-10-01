# ============================================================
# S3 Bucket for Storing Application Deployment Artifact
# ============================================================

resource "aws_s3_bucket" "app_artifacts" {
  bucket_prefix = "${local.name_prefix}-artifacts-"
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "app_package" {
  bucket = aws_s3_bucket.app_artifacts.id
  key    = "app.tar.gz"
  source = "${path.module}/app.tar.gz"
  etag   = filemd5("${path.module}/app.tar.gz")
}
