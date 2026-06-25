#!/usr/bin/env bash
# Deploy the TechStream self-healing stack to AWS.
set -euo pipefail

cd "$(dirname "$0")/../infrastructure/terraform"

echo "==> terraform init"
terraform init -input=false

echo "==> terraform validate"
terraform validate

echo "==> terraform plan"
terraform plan -out=tfplan

read -r -p "Apply this plan? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  terraform apply tfplan
  echo
  echo "==> Deployment complete. Key outputs:"
  terraform output
else
  echo "Aborted."
fi
