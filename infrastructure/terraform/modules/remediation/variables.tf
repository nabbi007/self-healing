variable "project_name" {
  description = "Name prefix applied to remediation resources."
  type        = string
}

variable "alarm_arn" {
  description = "ARN of the CloudWatch alarm that triggers remediation."
  type        = string
}

variable "lambda_source_file" {
  description = "Path to the Lambda handler source file to package."
  type        = string
}

variable "instance_tag_key" {
  description = "Tag key the Lambda uses to find instances to heal."
  type        = string
  default     = "SelfHealing"
}

variable "instance_tag_value" {
  description = "Tag value paired with instance_tag_key."
  type        = string
  default     = "enabled"
}
