variable "project_name" {
  description = "Name prefix applied to web-tier resources."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum instances in the ASG."
  type        = number
}

variable "asg_max_size" {
  description = "Maximum instances in the ASG."
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired instances in the ASG."
  type        = number
}

variable "vpc_id" {
  description = "VPC ID for the target group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ALB and ASG."
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for the launch template."
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "instance_security_group_id" {
  description = "Security group ID for the instances."
  type        = string
}

variable "app_code" {
  description = "Contents of app/main.py, injected into instance user-data."
  type        = string
}

variable "instance_tag_key" {
  description = "Tag key used by the remediation Lambda and DevOps Guru to find instances."
  type        = string
  default     = "SelfHealing"
}

variable "instance_tag_value" {
  description = "Tag value paired with instance_tag_key."
  type        = string
  default     = "enabled"
}
