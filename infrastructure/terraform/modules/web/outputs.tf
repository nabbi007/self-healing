output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.web.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used in CloudWatch metric dimensions."
  value       = aws_lb.web.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used in CloudWatch metric dimensions."
  value       = aws_lb_target_group.web.arn_suffix
}

output "asg_name" {
  description = "Auto Scaling Group name."
  value       = aws_autoscaling_group.web.name
}
