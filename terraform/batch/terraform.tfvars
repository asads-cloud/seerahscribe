region              = "eu-west-1"
ingest_bucket_name  = "seerahscribe-ingest-155186308102-eu-west-1"
results_bucket_name = "seerahscribe-results-155186308102-eu-west-1"
ecr_image_uri       = "155186308102.dkr.ecr.eu-west-1.amazonaws.com/whisper-faster:latest"


extra_tags = {
  Environment = "prod"
  Phase       = "3-aws-batch-gpu"
}

