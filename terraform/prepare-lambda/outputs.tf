output "ingest_bucket_id" {
  value = aws_s3_bucket.ingest.id
}

output "results_bucket_id" {
  value = aws_s3_bucket.results.id
}

output "prepare_lambda_arn" {
  value = aws_lambda_function.prepare.arn
}

output "ffmpeg_layer_arn" {
  value = aws_lambda_layer_version.ffmpeg.arn
}
