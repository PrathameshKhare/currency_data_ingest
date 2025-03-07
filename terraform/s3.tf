resource "aws_s3_bucket" "currency_data_bucket" {
  bucket = "currency-data-bucket"
}
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.currency_data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
# S3 bucket notification for ETL Lambda trigger
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.currency_data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.currency_etl.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "currency_data/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

# S3 bucket policy to allow Lambda execution
resource "aws_s3_bucket_policy" "allow_lambda_access" {
  bucket = aws_s3_bucket.currency_data_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowLambdaAccess"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.currency_data_bucket.arn}",
          "${aws_s3_bucket.currency_data_bucket.arn}/*"
        ]
      }
    ]
  })
}
