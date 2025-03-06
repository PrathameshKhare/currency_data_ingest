resource "aws_cloudwatch_event_rule" "every_hour_rule" {
  name                = "every_hour_rule"
  schedule_expression = "rate(1 hour)"
}

resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.currency_data_lambda.function_name
  principal     = "events.amazonaws.com"
  statement_id  = "AllowEventBridgeInvoke"
}

resource "aws_cloudwatch_event_target" "lambda_event_target" {
  rule      = aws_cloudwatch_event_rule.every_hour_rule.name
  target_id = "currency_data_lambda_target"
  arn       = aws_lambda_function.currency_data_lambda.arn
}
