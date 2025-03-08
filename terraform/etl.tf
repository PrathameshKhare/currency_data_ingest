# Lambda Layer for pandas
resource "aws_lambda_layer_version" "pandas_layer" {
  filename            = "${path.module}/layers/pandas_layer.zip"
  layer_name         = "pandas_layer"
  compatible_runtimes = ["python3.12"]
  description        = "Pandas layer for ETL processing"
}

# ETL Lambda Function
resource "aws_lambda_function" "currency_etl" {
  filename      = "etl_function.zip"
  function_name = "currency_etl"
  role          = aws_iam_role.lambda_role.arn
  handler       = "etl_processor.lambda_handler" # Updated to use lambda_handler
  runtime       = "python3.12"
  timeout       = 300
  memory_size   = 256

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.currency_data_bucket.id
    }
  }

  layers = [aws_lambda_layer_version.pandas_layer.arn]

  tags = {
    Name = "Currency Data ETL Processor"
    Type = "ETL"
  }
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.currency_etl.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.currency_data_bucket.arn
}

# S3 Event Trigger
resource "aws_s3_bucket_notification" "bucket_trigger" {
  bucket = aws_s3_bucket.currency_data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.currency_etl.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "currency_data/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}