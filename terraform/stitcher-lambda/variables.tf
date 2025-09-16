variable "region" {
  type = string 
}

variable "account_id" {
  type = string 
}

variable "project" {
  type    = string
  default = "seerahscribe"
}

variable "manifest_bucket" {
  type = string 
}

variable "results_bucket" {
  type = string 
}

# Prefixes with trailing slashes
variable "manifest_prefix" {
  type = string
  default = "manifests/" 
}

variable "chunks_prefix" {
  type = string
  default = "chunks/" 
}

variable "final_prefix" {
  type = string
  default = "final/" 
}

# integrations

variable "job_table_name" {
  type = string
  default = "" 
}

variable "sns_topic_arn" {
  type = string
  default = "" 
}

# Step Functions that will call this Lambda
variable "state_machine_arn" {
  type = string
  default = "" 
}
