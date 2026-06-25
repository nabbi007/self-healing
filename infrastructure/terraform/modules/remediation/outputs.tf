output "lambda_function_name" {
  description = "Name of the self-healing remediation Lambda."
  value       = aws_lambda_function.remediation.function_name
}

output "event_rule_name" {
  description = "Name of the EventBridge rule routing the alarm."
  value       = aws_cloudwatch_event_rule.alarm_state_change.name
}
