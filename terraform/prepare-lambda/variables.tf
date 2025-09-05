variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "project" {
  type    = string
  default = "seerahscribe"
}

# S3 bucket names
variable "ingest_bucket_name" {
  type    = string
  default = "whisper-xcribe-ingest"
}

variable "results_bucket_name" {
  type    = string
  default = "whisper-xcribe-results"
}

# Local artifact paths
variable "layer_zip_path" {
  type    = string
  default = "../../artifacts/layers/ffmpeg/ffmpeg-layer.zip"
}

variable "function_zip_path" {
  type    = string
  default = "../../artifacts/lambda/prepare.zip"
}

# restrict S3 trigger to these suffixes
variable "audio_suffixes" {
  type    = list(string)
  default = [".mp3", ".wav", ".m4a", ".mp4", ".mov", ".mkv", ".flac", ".ogg", ".opus"]
}
