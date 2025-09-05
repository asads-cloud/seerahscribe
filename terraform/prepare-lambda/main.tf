terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project = var.project
    Stack   = "prepare-lambda"
  }

  # Before (caused error): was told not compatible with this terraform?
  # layer_zip_abs    = abspath(joinpath(path.module, var.layer_zip_path))
  # function_zip_abs = abspath(joinpath(path.module, var.function_zip_path))

  # After (works across versions/OS):
  layer_zip_abs    = abspath("${path.module}/${var.layer_zip_path}")
  function_zip_abs = abspath("${path.module}/${var.function_zip_path}")
}

# --- S3 buckets ---
resource "aws_s3_bucket" "ingest" {
  bucket = var.ingest_bucket_name
  tags   = local.tags
}

# Upload the layer zip to S3 so Lambda can fetch it (avoids inline size limits)
resource "aws_s3_object" "ffmpeg_layer_zip" {
  bucket = aws_s3_bucket.results.id
  key    = "layers/ffmpeg/ffmpeg-layer.zip"
  source = local.layer_zip_abs
  etag   = filemd5(local.layer_zip_abs)
}

resource "aws_s3_bucket" "results" {
  bucket = var.results_bucket_name
  tags   = local.tags
}

# Block public access
resource "aws_s3_bucket_public_access_block" "ingest" {
  bucket                  = aws_s3_bucket.ingest.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_lambda_layer_version" "ffmpeg" {
  layer_name = "ffmpeg-layer"
  # filename            = local.layer_zip_abs           # REMOVED since changed upload to s3
  s3_bucket           = aws_s3_object.ffmpeg_layer_zip.bucket
  s3_key              = aws_s3_object.ffmpeg_layer_zip.key
  s3_object_version   = aws_s3_object.ffmpeg_layer_zip.version_id
  compatible_runtimes = ["python3.11"]
  description         = "Static ffmpeg/ffprobe under /opt/bin"
  # source_code_hash    = filebase64sha256(local.layer_zip_abs) # not needed when using S3+version
}

# --- IAM for Lambda ---
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "prepare_role" {
  name               = "prepare-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.tags
}

# CloudWatch logs + S3 access for read (audio) and write (chunks/manifests)
data "aws_iam_policy_document" "prepare_inline" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid     = "ReadSourceAudio"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.ingest.arn,
      "${aws_s3_bucket.ingest.arn}/audio/*"
    ]
  }

  statement {
    sid     = "WriteChunksAndManifests"
    actions = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"]
    resources = [
      "${aws_s3_bucket.ingest.arn}/chunks/*",
      "${aws_s3_bucket.ingest.arn}/manifests/*"
    ]
  }
}

resource "aws_iam_policy" "prepare_policy" {
  name   = "prepare-lambda-policy"
  policy = data.aws_iam_policy_document.prepare_inline.json
}

resource "aws_iam_role_policy_attachment" "attach_prepare" {
  role       = aws_iam_role.prepare_role.name
  policy_arn = aws_iam_policy.prepare_policy.arn
}

# --- Lambda Function: Prepare ---
resource "aws_lambda_function" "prepare" {
  function_name    = "prepare-chunking"
  role             = aws_iam_role.prepare_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  architectures    = ["x86_64"] # layer is amd64 static
  filename         = local.function_zip_abs
  source_code_hash = filebase64sha256(local.function_zip_abs)

  timeout     = 900
  memory_size = 2048
  layers      = [aws_lambda_layer_version.ffmpeg.arn]
  publish     = true

  environment {
    variables = {
      LOG_LEVEL            = "INFO"
      INGEST_BUCKET        = var.ingest_bucket_name
      CHUNK_PREFIX_BASE    = "chunks"
      MANIFEST_PREFIX_BASE = "manifests"
      CHUNK_LEN_SEC        = "600"
      OVERLAP_SEC          = "1"
      CHUNK_EXT            = "wav"
    }
  }

  tags = local.tags

  depends_on = [
    aws_s3_bucket_public_access_block.ingest
  ]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.prepare.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingest.arn
}

# --- S3 -> Lambda event notifications (prefix=audio/) ---
# Create one block per suffix so we accept common audio containers.
resource "aws_s3_bucket_notification" "ingest_events" {
  bucket = aws_s3_bucket.ingest.id

  dynamic "lambda_function" {
    for_each = var.audio_suffixes
    content {
      lambda_function_arn = aws_lambda_function.prepare.arn
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = "audio/"
      filter_suffix       = lambda_function.value
    }
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
