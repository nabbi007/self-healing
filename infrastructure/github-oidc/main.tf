# =====================================================================
# GitHub Actions OIDC trust + deploy role
# ---------------------------------------------------------------------
# Run this ONCE, manually, with admin credentials, to let the GitHub
# Actions "Deploy" workflow assume an AWS role using short-lived OIDC
# tokens — no long-lived access keys stored in GitHub.
#
#   cd infrastructure/github-oidc
#   terraform init
#   terraform apply -var="github_repo=YOUR_ORG/YOUR_REPO"
#
# Then copy the `deploy_role_arn` output into the GitHub repo variable
# AWS_DEPLOY_ROLE_ARN (see README).
# =====================================================================

# Fetch GitHub's OIDC TLS cert so we can pin its thumbprint dynamically.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# Trust policy: only this repo's workflows may assume the role, and only
# with the sts.amazonaws.com audience.
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  description        = "Assumed by GitHub Actions to deploy the TechStream self-healing stack."
}

# Permissions the Terraform stack needs to create/destroy its resources.
# Broad-by-service for this lab; tighten to specific ARNs for production.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "StackServices"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "lambda:*",
      "events:*",
      "cloudwatch:*",
      "logs:*",
      "ssm:*",
      "devops-guru:*",
      "iam:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*",
    ]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
