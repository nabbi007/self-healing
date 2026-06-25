variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name prefix applied to all resources."
  type        = string
  default     = "techstream"
}

variable "instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "error_rate_threshold_percent" {
  description = "Error-rate percentage that trips the CloudWatch alarm (lab requires > 5%)."
  type        = number
  default     = 5
}

variable "allowed_ingress_cidr" {
  description = "CIDR allowed to reach the ALB on port 80. Lock this to your IP for a real deployment."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_devops_guru" {
  description = "Whether to enable Amazon DevOps Guru on this stack (incurs cost)."
  type        = bool
  default     = true
}

variable "instance_tag_key" {
  description = "Tag key used to identify self-healing instances (shared by the web and remediation modules)."
  type        = string
  default     = "SelfHealing"
}

variable "instance_tag_value" {
  description = "Tag value paired with instance_tag_key."
  type        = string
  default     = "enabled"
}
