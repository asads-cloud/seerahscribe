output "step_functions_role_arn" {
  description = "ARN of the Step Functions service role"
  value       = aws_iam_role.sf_role.arn
}

output "state_logs_group_name" {
  description = "CloudWatch Logs group for state machine"
  value       = aws_cloudwatch_log_group.sf_logs.name
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.whisper_map.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.whisper_map.name
}