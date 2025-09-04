data "aws_caller_identity" "me" {}
data "aws_region" "here" {}

locals {
  project = "seerahscribe"
  bucket  = "${local.project}-${data.aws_caller_identity.me.account_id}-${data.aws_region.here.name}-dev"
}

resource "aws_s3_bucket" "worker_test" {
  bucket = local.bucket
}

resource "aws_s3_bucket_public_access_block" "worker_test" {
  bucket                  = aws_s3_bucket.worker_test.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "test_bucket_name" { value = aws_s3_bucket.worker_test.bucket }
