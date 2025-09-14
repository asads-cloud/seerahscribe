output "batch_service_role_arn" {
  value = aws_iam_role.batch_service.arn
}

output "ecs_instance_profile_arn" {
  value = aws_iam_instance_profile.ecs_instance_profile.arn
}

output "batch_job_role_arn" {
  value = aws_iam_role.batch_job_role.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.batch_jobs.name
}

output "job_queue_arn" {
  value = aws_batch_job_queue.gpu_queue.arn
}

output "job_definition_arn" {
  value = aws_batch_job_definition.whisper_job.arn
}
