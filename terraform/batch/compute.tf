locals {
  compute_env_name = "whisper-gpu-env"
}

resource "aws_batch_compute_environment" "gpu_env" {
  compute_environment_name = local.compute_env_name
  type                     = "MANAGED"
  state                    = "ENABLED"
  service_role             = aws_iam_role.batch_service.arn
  tags = {
    Project = "seerahscribe"
    Phase   = "3-aws-batch-gpu"
  }

  compute_resources {
    type                = "EC2"
    allocation_strategy = "BEST_FIT_PROGRESSIVE"
    min_vcpus           = 0
    desired_vcpus       = 0
    max_vcpus           = 8

    # singular here:
    instance_type = ["g5.xlarge"]


    subnets            = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.batch_instances.id]

    ec2_configuration {
      image_type = "ECS_AL2_NVIDIA"
    }

    # must be the *instance profile* ARN
    instance_role = aws_iam_instance_profile.ecs_instance_profile.arn
  }
}


# (Optional) If you decide you need a bigger root volume later:
# resource "aws_launch_template" "batch_gpu" {
#   name_prefix   = "batch-gpu-"
#   update_default_version = true
#   block_device_mappings {
#     device_name = "/dev/xvda"
#     ebs {
#       volume_size = 100
#       volume_type = "gp3"
#     }
#   }
# }
