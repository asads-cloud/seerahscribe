locals {
  ingest_bucket_arn  = "arn:aws:s3:::${var.ingest_bucket_name}"
  results_bucket_arn = "arn:aws:s3:::${var.results_bucket_name}"
}

resource "aws_cloudwatch_log_group" "sf_logs" {
  name              = var.log_group_name
  retention_in_days = 30
}

data "aws_iam_policy_document" "sf_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "sf_role" {
  name                 = "whisper-transcribe-steps-role"
  assume_role_policy   = data.aws_iam_policy_document.sf_assume_role.json
  force_detach_policies = true
  tags = {
    Project = "SeerahScribe"
    Phase   = "4"
  }
}

data "aws_iam_policy_document" "sf_policy" {
  # Batch submit/describe
  statement {
    sid     = "BatchSubmitDescribe"
    effect  = "Allow"
    actions = ["batch:SubmitJob", "batch:DescribeJobs"]
    resources = ["*"]
  }

  # Allow Distributed Map to start a Map Run / child executions
  statement {
    sid     = "StartExecutionsForDistributedMap"
    effect  = "Allow"
    actions = ["states:StartExecution"]
    resources = [
      "arn:aws:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:whisper-transcribe-map"
    ]
  }

  # EventBridge (required for Step Functions .sync)
  statement {
    sid     = "EventsForSync"
    effect  = "Allow"
    actions = [
      "events:PutTargets",
      "events:PutRule",
      "events:DescribeRule",
      "events:DeleteRule",
      "events:RemoveTargets"
    ]
    resources = ["*"]
  }

  # Optional Lambda invoke (restrict if you pass specific ARNs)
  statement {
    sid     = "InvokeLambda"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction", "lambda:InvokeAsync"]
    resources = length(var.lambda_function_arns) > 0 ? var.lambda_function_arns : ["*"]
  }

  # S3 read: ingest bucket
  statement {
    sid     = "S3ReadIngest"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:ListBucket"
    ]
    resources = [
      local.ingest_bucket_arn,
      "${local.ingest_bucket_arn}/*"
    ]
  }

  # S3 read: results bucket
  statement {
    sid     = "S3ReadResults"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:ListBucket"
    ]
    resources = [
      local.results_bucket_arn,
      "${local.results_bucket_arn}/*"
    ]
  }

  # Vended logs delivery permissions
  statement {
    sid     = "LogsVendedPermissions"
    effect  = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sf_inline" {
  name   = "whisper-transcribe-steps-policy"
  role   = aws_iam_role.sf_role.id
  policy = data.aws_iam_policy_document.sf_policy.json
}
