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
    Stack   = "stitcher-lambda"
  }

  # Path to prebuilt zip in artifacts/lambda/
  function_zip_abs = abspath("${path.module}/../../artifacts/lambda/stitcher.zip")
}

# --- IAM role for Lambda ---
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "stitcher_role" {
  name               = "whisper-stitcher-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

# CloudWatch logs + S3 access
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid     = "ReadManifest"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.manifest_bucket}",
      "arn:aws:s3:::${var.manifest_bucket}/${var.manifest_prefix}*"
    ]
  }

  statement {
    sid     = "ReadChunks"
    actions = ["s3:GetObject", "s3:ListBucket", "s3:HeadObject"]
    resources = [
      "arn:aws:s3:::${var.results_bucket}",
      "arn:aws:s3:::${var.results_bucket}/${var.chunks_prefix}*"
    ]
  }

  statement {
    sid     = "WriteFinals"
    actions = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.results_bucket}",
      "arn:aws:s3:::${var.results_bucket}/${var.final_prefix}*"
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "whisper-stitcher-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
}

resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.stitcher_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# --- Optional: DynamoDB ---
data "aws_iam_policy_document" "ddb_access" {
  count = var.job_table_name == "" ? 0 : 1

  statement {
    actions   = ["dynamodb:UpdateItem", "dynamodb:PutItem", "dynamodb:GetItem"]
    resources = ["arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.job_table_name}"]
  }
}

resource "aws_iam_policy" "ddb_access" {
  count  = var.job_table_name == "" ? 0 : 1
  name   = "whisper-stitcher-ddb-access"
  policy = data.aws_iam_policy_document.ddb_access[0].json
}

resource "aws_iam_role_policy_attachment" "ddb_attach" {
  count      = var.job_table_name == "" ? 0 : 1
  role       = aws_iam_role.stitcher_role.name
  policy_arn = aws_iam_policy.ddb_access[0].arn
}

# --- Optional: SNS ---
data "aws_iam_policy_document" "sns_access" {
  count = var.sns_topic_arn == "" ? 0 : 1

  statement {
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_policy" "sns_access" {
  count  = var.sns_topic_arn == "" ? 0 : 1
  name   = "whisper-stitcher-sns-access"
  policy = data.aws_iam_policy_document.sns_access[0].json
}

resource "aws_iam_role_policy_attachment" "sns_attach" {
  count      = var.sns_topic_arn == "" ? 0 : 1
  role       = aws_iam_role.stitcher_role.name
  policy_arn = aws_iam_policy.sns_access[0].arn
}

# --- Lambda function ---
resource "aws_lambda_function" "stitcher" {
  function_name = "whisper-stitcher"
  role          = aws_iam_role.stitcher_role.arn
  runtime       = "python3.11"

  # Flat zip -> handler.py at zip root
  handler          = "handler.handler"
  filename         = local.function_zip_abs
  source_code_hash = filebase64sha256(local.function_zip_abs)

  timeout     = 900
  memory_size = 1024
  publish     = true

  environment {
    variables = {
      OVERLAP_SECONDS     = "1.0"
      MIN_SEGMENT_SECONDS = "0.06"
      JOB_TABLE_NAME      = var.job_table_name
      SNS_TOPIC_ARN       = var.sns_topic_arn
    }
  }

  tags = local.tags
}

resource "aws_lambda_function_event_invoke_config" "stitcher_async" {
  function_name                = aws_lambda_function.stitcher.function_name
  maximum_retry_attempts       = 0
  maximum_event_age_in_seconds = 60
}

# Allow Step Functions to invoke Lambda
resource "aws_lambda_permission" "allow_sfn" {
  count         = var.state_machine_arn == "" ? 0 : 1
  statement_id  = "AllowSFNInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stitcher.function_name
  principal     = "states.amazonaws.com"
  source_arn    = var.state_machine_arn
}
