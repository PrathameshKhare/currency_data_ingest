resource "aws_iam_role" "lambda_role" {
  name               = "currency_api_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name   = "lambda_s3_policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:PutObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.currency_data_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_cloudwatch_policy" {
  name = "lambda_cloudwatch_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role" "etl_lambda_role" {
  name = "currency_etl_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "etl_s3_policy" {
  name = "etl_s3_policy"
  role = aws_iam_role.etl_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.currency_data_bucket.arn}/*",
          aws_s3_bucket.currency_data_bucket.arn
        ]
      }
    ]
  })
}
