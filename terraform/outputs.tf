output "lambda_function_arn" {
  value = aws_lambda_function.currency_data_lambda.arn
}

output "s3_bucket_name" {
  value = aws_s3_bucket.currency_data_bucket.bucket
}
