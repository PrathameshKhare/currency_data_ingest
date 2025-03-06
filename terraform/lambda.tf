resource "aws_lambda_function" "currency_data_lambda" {
  filename         = "lambda_function.zip"
  function_name    = "currency_data_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      SECRET_NAME   = "FIXER_CURRENCY_API_KEY"
      S3_BUCKET_NAME = aws_s3_bucket.currency_data_bucket.bucket
    }
  }
}
