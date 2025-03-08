# Create Athena Workgroup
resource "aws_athena_workgroup" "currency_analysis" {
  name = "currency_analysis"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.currency_data_bucket.id}/athena-results/"
    }
  }
}