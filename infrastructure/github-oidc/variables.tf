variable "aws_region" {
  description = "AWS region (the deploy role is global, but the provider needs a region)."
  type        = string
  default     = "eu-west-1"
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the role, as 'owner/repo'."
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume."
  type        = string
  default     = "techstream-github-deploy"
}

variable "state_bucket" {
  description = "Name of the S3 bucket holding Terraform state (for least-privilege S3 access)."
  type        = string
  default     = "techstream-terraform-state"
}
