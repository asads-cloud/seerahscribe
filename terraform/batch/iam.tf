# ---------------------------
# Batch service role
# ---------------------------
resource "aws_iam_role" "batch_service" {
  name               = "AWSBatchServiceRole"
  assume_role_policy = data.aws_iam_policy_document.batch_service_trust.json
  tags               = { ManagedBy = "Terraform" }
}

data "aws_iam_policy_document" "batch_service_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "batch_service_managed" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# ---------------------------
# ECS instance role + instance profile for EC2 hosts
# ---------------------------
resource "aws_iam_role" "ecs_instance_role" {
  name               = "ecsInstanceRole"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { ManagedBy = "Terraform" }
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Attach common policies so instances can join ECS, pull ECR, use SSM/CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_instance_ecs" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ecr_ro" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_cwagent" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceRole"
  role = aws_iam_role.ecs_instance_role.name
}

# ---------------------------
# Job role for containers (S3 R/W to ingest and results)
# ---------------------------
resource "aws_iam_role" "batch_job_role" {
  name               = "batch_job_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = { ManagedBy = "Terraform" }
}

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "job_s3_access" {
  statement {
    sid = "S3ReadWriteIngestAndResults"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.ingest_bucket_name}",
      "arn:aws:s3:::${var.ingest_bucket_name}/*",
      "arn:aws:s3:::${var.results_bucket_name}",
      "arn:aws:s3:::${var.results_bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "job_s3_access" {
  name   = "batch_job_s3_access"
  policy = data.aws_iam_policy_document.job_s3_access.json
}

resource "aws_iam_role_policy_attachment" "job_role_attach_s3" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.job_s3_access.arn
}
