data "aws_secretsmanager_secret" "existing_fixer_api" {
  name = "fixer_api_credentials"
}
