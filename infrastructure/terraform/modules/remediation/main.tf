# =====================================================================
# Lambda remediation role — least privilege
# =====================================================================
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name_prefix        = "${var.project_name}-remediation-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# The Lambda only needs to: send the restart command to our tagged instances,
# discover those instances, and read the alarm context.
data "aws_iam_policy_document" "lambda_remediation" {
  statement {
    sid    = "RunRestartCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DiscoverInstances"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:SetDesiredCapacity",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadAlarmContext"
    effect    = "Allow"
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_remediation" {
  name_prefix = "${var.project_name}-remediation-"
  role        = aws_iam_role.lambda.id
  policy      = data.aws_iam_policy_document.lambda_remediation.json
}

# =====================================================================
# Package the Lambda from the supplied handler source
# (boto3 is already present in the Lambda runtime — no deps to bundle)
# =====================================================================
data "archive_file" "remediation" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/.build/remediation.zip"
}

resource "aws_lambda_function" "remediation" {
  function_name    = "${var.project_name}-remediation"
  description      = "Restarts the techstream service via SSM when the error-rate alarm fires."
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.remediation.output_path
  source_code_hash = data.archive_file.remediation.output_base64sha256

  environment {
    variables = {
      INSTANCE_TAG_KEY   = var.instance_tag_key
      INSTANCE_TAG_VALUE = var.instance_tag_value
    }
  }
}

# Retain Lambda logs for a bounded period (cost hygiene)
resource "aws_cloudwatch_log_group" "remediation" {
  name              = "/aws/lambda/${aws_lambda_function.remediation.function_name}"
  retention_in_days = 14
}

# =====================================================================
# EventBridge rule: catch the alarm transitioning INTO the ALARM state
# =====================================================================
resource "aws_cloudwatch_event_rule" "alarm_state_change" {
  name        = "${var.project_name}-error-rate-alarm"
  description = "Route the high-error-rate alarm into the remediation Lambda."

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    resources   = [var.alarm_arn]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "remediation" {
  rule      = aws_cloudwatch_event_rule.alarm_state_change.name
  target_id = "remediation-lambda"
  arn       = aws_lambda_function.remediation.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_state_change.arn
}
