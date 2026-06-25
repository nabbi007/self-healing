output "alarm_arn" {
  description = "ARN of the error-rate alarm (consumed by the remediation module)."
  value       = aws_cloudwatch_metric_alarm.error_rate.arn
}

output "alarm_name" {
  description = "Name of the error-rate alarm."
  value       = aws_cloudwatch_metric_alarm.error_rate.alarm_name
}

output "dashboard_name" {
  description = "Name of the Golden Signals dashboard."
  value       = aws_cloudwatch_dashboard.golden_signals.dashboard_name
}
