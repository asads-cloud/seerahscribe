variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "ingest_bucket_name" {
  description = "S3 ingest bucket name"
  type        = string
}

variable "results_bucket_name" {
  description = "S3 results bucket name"
  type        = string
}

variable "extra_tags" {
  description = "Optional extra tags"
  type        = map(string)
  default     = {}
}

variable "ecr_image_uri" {
  description = "Full ECR image URI for whisper-faster:latest"
  type        = string
}
