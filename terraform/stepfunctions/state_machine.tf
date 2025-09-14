locals {
  asl_definition = templatefile("${path.module}/state_machine.asl.json.tftpl", {
    batch_job_queue_arn       = var.batch_job_queue_arn
    batch_job_definition_arn  = var.batch_job_definition_arn
    map_max_concurrency       = var.map_max_concurrency
    batch_override_vcpus      = var.batch_override_vcpus
    batch_override_memory_mib = var.batch_override_memory_mib
  })
}


resource "aws_sfn_state_machine" "whisper_map" {
  name       = var.state_machine_name
  role_arn   = aws_iam_role.sf_role.arn
  definition = local.asl_definition
  type       = "STANDARD"




  

  # CloudWatch vended logs
  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.sf_logs.arn}:*"
  }

  tags = { Project = "SeerahScribe", Phase = "4" }
}

data "aws_caller_identity" "current" {}
