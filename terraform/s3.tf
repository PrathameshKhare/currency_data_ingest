resource "aws_s3_bucket" "currency_data_bucket" {
  bucket = "currency-data-bucket"
}
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.currency_data_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}