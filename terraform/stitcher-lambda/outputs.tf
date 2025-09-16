output "lambda_name" {
  value = aws_lambda_function.stitcher.function_name
}
output "lambda_arn"  {
  value = aws_lambda_function.stitcher.arn 
}

