variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "results_bucket_name" {
  description = "Results bucket name (e.g., seerahscribe-results-<acct>-eu-west-1)"
  type        = string
}

variable "ingest_bucket_name" {
  description = "Ingest bucket name (e.g., seerahscribe-ingest-<acct>-eu-west-1)"
  type        = string
}

variable "lambda_function_arns" {
  description = "List of Lambda ARNs this Step Function may invoke (optional; can be empty)"
  type        = list(string)
  default     = []
}

variable "log_group_name" {
  description = "CloudWatch Logs group for Step Functions vended logs"
  type        = string
  default     = "/aws/vendedlogs/states/whisper-transcribe"
}

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "whisper-transcribe-map"
}

variable "map_max_concurrency" {
  description = "Max parallel child workflows in Distributed Map"
  type        = number
  default     = 10
}

variable "batch_job_queue_arn" {
  description = "AWS Batch Job Queue ARN (from Phase 3)"
  type        = string
}

variable "batch_job_definition_arn" {
  description = "AWS Batch Job Definition ARN (from Phase 3)"
  type        = string
}

variable "batch_override_vcpus" {
  description = "Container vCPU override for Batch job"
  type        = number
  default     = 4
}

variable "batch_override_memory_mib" {
  description = "Container memory MiB override for Batch job"
  type        = number
  default     = 10000
}
