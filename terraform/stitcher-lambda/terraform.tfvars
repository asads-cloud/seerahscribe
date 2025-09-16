region          = "eu-west-1"
account_id      = "155186308102"
manifest_bucket = "seerahscribe-ingest-155186308102-eu-west-1"
results_bucket  = "seerahscribe-results-155186308102-eu-west-1"

# The Step Functions state machine that will call this Lambda
state_machine_arn = "arn:aws:states:eu-west-1:155186308102:stateMachine:whisper-transcribe-map"

# Optional (leave as "" to disable DDB/SNS integration)
job_table_name = ""
sns_topic_arn  = ""
