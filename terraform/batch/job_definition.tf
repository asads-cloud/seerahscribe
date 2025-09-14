locals {
  job_definition_name = "whisper-transcribe-job"
}

resource "aws_batch_job_definition" "whisper_job" {
  name                  = local.job_definition_name
  type                  = "container"
  platform_capabilities = ["EC2"]

  container_properties = jsonencode({
    image      = var.ecr_image_uri
    jobRoleArn = aws_iam_role.batch_job_role.arn

    command = [] # we'll override when submitting jobs
    vcpus   = 4
    memory  = 16000

    resourceRequirements = [
      { type = "GPU", value = "1" }
    ]

    environment = [
      { name = "MODEL", value = "large-v3" },
      { name = "LANGUAGE", value = "auto" },
      { name = "COMPUTE_TYPE", value = "int8_float16" },
      { name = "CHUNK_S3_URI", value = "" },
      { name = "RESULTS_BUCKET", value = "" },
      { name = "RESULTS_PREFIX", value = "chunks/" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/aws/batch/job"
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "whisper"
      }
    }

    readonlyRootFilesystem = false
    privileged             = false
    ulimits                = []
    volumes                = []
    mountPoints            = []
  })

  retry_strategy {
    attempts = 2
    evaluate_on_exit {
      on_status_reason = "Host EC2*"
      action           = "RETRY"
    }
  }

  timeout { attempt_duration_seconds = 7200 }

  tags = { Project = "seerahscribe", Phase = "3-aws-batch-gpu" }
}
