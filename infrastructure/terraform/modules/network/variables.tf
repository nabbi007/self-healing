variable "project_name" {
  description = "Name prefix applied to network resources."
  type        = string
}

variable "allowed_ingress_cidr" {
  description = "CIDR allowed to reach the ALB on port 80."
  type        = string
}
