# =====================================================================
# TechStream Self-Healing System — root module
# Wires together the network, web, monitoring, remediation and
# DevOps Guru modules into the full self-healing pipeline.
# =====================================================================

# Networking: default VPC/subnets, AMI lookup, security groups
module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  allowed_ingress_cidr = var.allowed_ingress_cidr
}

# Web tier: ALB + Auto Scaling Group running the FastAPI app
module "web" {
  source = "./modules/web"

  project_name         = var.project_name
  instance_type        = var.instance_type
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity

  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.subnet_ids
  ami_id                     = module.network.ami_id
  alb_security_group_id      = module.network.alb_security_group_id
  instance_security_group_id = module.network.instance_security_group_id

  instance_tag_key   = var.instance_tag_key
  instance_tag_value = var.instance_tag_value

  # The app source is baked into instance user-data at plan time.
  app_code = file("${path.module}/../../app/main.py")
}

# Monitoring: Golden Signals dashboard + error-rate alarm
module "monitoring" {
  source = "./modules/monitoring"

  project_name                 = var.project_name
  aws_region                   = var.aws_region
  alb_arn_suffix               = module.web.alb_arn_suffix
  target_group_arn_suffix      = module.web.target_group_arn_suffix
  asg_name                     = module.web.asg_name
  error_rate_threshold_percent = var.error_rate_threshold_percent
}

# Self-healing: alarm -> EventBridge -> Lambda -> SSM restart
module "remediation" {
  source = "./modules/remediation"

  project_name       = var.project_name
  alarm_arn          = module.monitoring.alarm_arn
  lambda_source_file = "${path.module}/../lambda/handler.py"
  instance_tag_key   = var.instance_tag_key
  instance_tag_value = var.instance_tag_value
}

# AI analysis: DevOps Guru over the tagged stack
module "devops_guru" {
  source = "./modules/devops-guru"

  enable_devops_guru = var.enable_devops_guru
}
