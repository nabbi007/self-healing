output "alb_url" {
  description = "Public URL of the web application (and chaos endpoints)."
  value       = "http://${module.web.alb_dns_name}"
}

output "dashboard_url" {
  description = "Direct link to the Golden Signals CloudWatch dashboard."
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${module.monitoring.dashboard_name}"
}

output "alarm_name" {
  description = "Name of the error-rate alarm that triggers self-healing."
  value       = module.monitoring.alarm_name
}

output "remediation_lambda" {
  description = "Name of the self-healing remediation Lambda."
  value       = module.remediation.lambda_function_name
}

output "asg_name" {
  description = "Auto Scaling Group name."
  value       = module.web.asg_name
}
