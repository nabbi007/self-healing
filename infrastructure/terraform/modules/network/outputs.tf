output "vpc_id" {
  description = "ID of the default VPC."
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Subnet IDs used by the ALB and ASG."
  value       = data.aws_subnets.default.ids
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI ID for the web tier."
  value       = data.aws_ssm_parameter.al2023.value
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB."
  value       = aws_security_group.alb.id
}

output "instance_security_group_id" {
  description = "Security group ID for the web instances."
  value       = aws_security_group.instance.id
}
