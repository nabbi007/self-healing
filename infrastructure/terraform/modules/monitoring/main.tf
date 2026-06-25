# =====================================================================
# Error-rate alarm (lab requirement: trip when error rate > 5%)
# Computed via metric math from ALB 5XX count / total request count.
# A CloudWatch alarm state change is automatically published to the
# default EventBridge bus — that is what drives the self-healing Lambda.
# =====================================================================
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  alarm_description   = "Target 5XX error rate exceeded ${var.error_rate_threshold_percent}% — self-healing triggered."
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_rate_threshold_percent
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "100 * (errors) / (requests + 0.0001)"
    label       = "5XX error rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      stat        = "Sum"
      period      = 60
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }

  metric_query {
    id = "requests"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      stat        = "Sum"
      period      = 60
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }
}

# =====================================================================
# Golden Signals dashboard: Latency, Traffic, Errors, Saturation
# =====================================================================
resource "aws_cloudwatch_dashboard" "golden_signals" {
  dashboard_name = "${var.project_name}-golden-signals"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2,
        properties = {
          markdown = "# TechStream — Golden Signals\nLatency · Traffic · Errors · Saturation. Error-rate alarm trips at **> ${var.error_rate_threshold_percent}%** and triggers automated remediation."
        }
      },
      {
        type = "metric", x = 0, y = 2, width = 12, height = 6,
        properties = {
          title  = "Latency — Target Response Time (s)",
          region = var.aws_region,
          view   = "timeSeries",
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "avg" }],
            ["...", { stat = "p99", label = "p99" }],
            ["...", { stat = "p50", label = "p50" }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 2, width = 12, height = 6,
        properties = {
          title  = "Traffic — Requests per minute",
          region = var.aws_region,
          view   = "timeSeries",
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60 }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 8, width = 12, height = 6,
        properties = {
          title  = "Errors — 5XX count & error rate (%)",
          region = var.aws_region,
          view   = "timeSeries",
          yAxis  = { right = { min = 0, max = 100 } },
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, label = "Target 5XX" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, label = "ELB 5XX" }],
            [{ expression = "100 * m5xx / (mreq + 0.0001)", label = "Error rate %", yAxis = "right", id = "erate" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, id = "m5xx", visible = false }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 60, id = "mreq", visible = false }]
          ],
          annotations = {
            horizontal = [{ label = "Alarm threshold", value = var.error_rate_threshold_percent, yAxis = "right" }]
          }
        }
      },
      {
        type = "metric", x = 12, y = 8, width = 12, height = 6,
        properties = {
          title  = "Saturation — CPU & Memory (%)",
          region = var.aws_region,
          view   = "timeSeries",
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average", label = "CPU %" }],
            ["TechStream/EC2", "mem_used_percent", "AutoScalingGroupName", var.asg_name, { stat = "Average", label = "Memory %" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 14, width = 12, height = 6,
        properties = {
          title  = "Healthy vs Unhealthy hosts",
          region = var.aws_region,
          view   = "timeSeries",
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Healthy" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", var.target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix, { stat = "Average", label = "Unhealthy" }]
          ]
        }
      },
      {
        type = "alarm", x = 12, y = 14, width = 12, height = 6,
        properties = {
          title  = "Self-healing alarm",
          alarms = [aws_cloudwatch_metric_alarm.error_rate.arn]
        }
      }
    ]
  })
}
