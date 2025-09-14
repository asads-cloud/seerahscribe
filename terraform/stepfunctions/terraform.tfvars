region          = "eu-west-1"
ingest_bucket_name  = "seerahscribe-ingest-155186308102-eu-west-1"
results_bucket_name = "seerahscribe-results-155186308102-eu-west-1"

# If you want to restrict Lambda invoke now, drop ARNs here; else leave empty.
lambda_function_arns = []
# Example (uncomment + replace if desired):
# lambda_function_arns = [
#   "arn:aws:lambda:eu-west-1:155186308102:function:prepare-stitch-inputs",
# ]

batch_job_queue_arn      = "arn:aws:batch:eu-west-1:155186308102:job-queue/whisper-gpu-queue"
batch_job_definition_arn = "arn:aws:batch:eu-west-1:155186308102:job-definition/whisper-transcribe-job:2" # note :2
map_max_concurrency      = 10
state_machine_name       = "whisper-transcribe-map"

batch_override_vcpus     = 4
batch_override_memory_mib= 10000
