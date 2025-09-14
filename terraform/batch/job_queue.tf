locals {
  job_queue_name = "whisper-gpu-queue"
}

resource "aws_batch_job_queue" "gpu_queue" {
  name     = local.job_queue_name
  state    = "ENABLED"
  priority = 1

  # Provider v5.x syntax
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.gpu_env.arn
  }

  tags = {
    Project = "seerahscribe"
    Phase   = "3-aws-batch-gpu"
  }
}
