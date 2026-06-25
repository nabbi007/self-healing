#!/usr/bin/env bash
# Tail the self-healing pipeline: alarm state + Lambda logs.
# Helps you watch the system heal itself in real time.
set -euo pipefail

cd "$(dirname "$0")/../infrastructure/terraform"

ALARM=$(terraform output -raw alarm_name)
LAMBDA=$(terraform output -raw remediation_lambda)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "${AWS_REGION:-eu-central-1}")

echo "==> Current alarm state for: $ALARM"
aws cloudwatch describe-alarms --alarm-names "$ALARM" \
  --query 'MetricAlarms[0].{State:StateValue,Reason:StateReason}' --output table

echo
echo "==> Tailing remediation Lambda logs (Ctrl+C to stop)..."
aws logs tail "/aws/lambda/${LAMBDA}" --follow --since 10m
