variable "project_name" {
  description = "Name prefix applied to monitoring resources."
  type        = string
}

variable "aws_region" {
  description = "Region used in dashboard widget definitions."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metric dimensions."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch metric dimensions."
  type        = string
}

variable "asg_name" {
  description = "Auto Scaling Group name for saturation metrics."
  type        = string
}

variable "error_rate_threshold_percent" {
  description = "Error-rate percentage that trips the alarm."
  type        = number
}
