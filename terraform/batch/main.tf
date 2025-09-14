terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  project = "seerahscribe"
  tags = merge({
    Project = local.project
    Owner   = "seerahscribe"
  }, var.extra_tags)
}

resource "aws_cloudwatch_log_group" "batch_jobs" {
  name              = "/aws/batch/job"
  retention_in_days = 14
  tags              = local.tags
}
