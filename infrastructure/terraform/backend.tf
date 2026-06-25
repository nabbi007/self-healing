terraform {
  # Remote state in S3 with native S3 state locking (Terraform >= 1.10).
  # No DynamoDB table required — `use_lockfile` uses an S3 object lock.
  #
  # `bucket` is intentionally omitted here (partial configuration). Supply it
  # at init time so the environment-specific name stays out of version control:
  #
  #   terraform init -backend-config="bucket=YOUR_BUCKET_NAME" -migrate-state
  #
  # or, using the provided file:
  #
  #   terraform init -backend-config=backend.hcl -migrate-state
  backend "s3" {
    bucket       = "techstream-terraform-state"
    key          = "techstream/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
