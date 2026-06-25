# =====================================================================
# EC2 instance role — managed by SSM (no SSH keys), emits CloudWatch data
# =====================================================================
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name_prefix        = "${var.project_name}-instance-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Enables SSM Run Command + Session Manager (how the Lambda heals the box)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the CloudWatch agent push metrics/logs
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.project_name}-instance-"
  role        = aws_iam_role.instance.name
}

# =====================================================================
# Launch template — defines how each web instance is built
# =====================================================================
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  vpc_security_group_ids = [var.instance_security_group_id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh.tftpl", {
    app_code = var.app_code
  }))

  # Detailed (1-minute) monitoring so the alarm reacts quickly
  monitoring {
    enabled = true
  }

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only — best practice
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web"
      Role = "web-server"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =====================================================================
# Application Load Balancer + target group + listener
# Source of 3 Golden Signals: latency, traffic, errors
# =====================================================================
resource "aws_lb" "web" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 4
    interval            = 10
    matcher             = "200"
  }

  # Faster deregistration so unhealthy/restarting instances drop out quickly
  deregistration_delay = 30
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# =====================================================================
# Auto Scaling Group
# =====================================================================
resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300 # instances need a few minutes to install Python + the app

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # Roll instances when the launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web"
    propagate_at_launch = true
  }

  # DevOps Guru and the remediation Lambda find instances by this tag
  tag {
    key                 = var.instance_tag_key
    value               = var.instance_tag_value
    propagate_at_launch = true
  }
}
