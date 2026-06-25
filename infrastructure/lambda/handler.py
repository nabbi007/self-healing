import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client("ssm")
ec2 = boto3.client("ec2")

INSTANCE_TAG_KEY = os.environ.get("INSTANCE_TAG_KEY", "SelfHealing")
INSTANCE_TAG_VALUE = os.environ.get("INSTANCE_TAG_VALUE", "enabled")

# Restart the service AND clear any injected chaos so the demo recovers cleanly.
REMEDIATION_COMMANDS = [
    "systemctl restart techstream.service",
    "sleep 3",
    "curl -s -X DELETE http://localhost:8000/chaos || true",
    "systemctl is-active techstream.service",
]


def _find_target_instances():
    """Return instance IDs that are running and carry the self-healing tag."""
    resp = ec2.describe_instances(
        Filters=[
            {"Name": f"tag:{INSTANCE_TAG_KEY}", "Values": [INSTANCE_TAG_VALUE]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ]
    )
    return [
        inst["InstanceId"]
        for reservation in resp["Reservations"]
        for inst in reservation["Instances"]
    ]


def handler(event, context):
    logger.info("Remediation triggered. Event: %s", json.dumps(event))

    # Tolerate both EventBridge alarm-state-change events and manual test invokes
    alarm_name = (
        event.get("detail", {}).get("alarmName")
        or event.get("alarmName")
        or "manual-invocation"
    )

    instance_ids = _find_target_instances()
    if not instance_ids:
        logger.warning("No self-healing instances found — nothing to remediate.")
        return {"status": "no_targets", "alarm": alarm_name}

    logger.info("Restarting techstream on instances: %s", instance_ids)

    response = ssm.send_command(
        InstanceIds=instance_ids,
        DocumentName="AWS-RunShellScript",
        Comment=f"Self-healing restart triggered by {alarm_name}",
        Parameters={"commands": REMEDIATION_COMMANDS},
        CloudWatchOutputConfig={"CloudWatchOutputEnabled": True},
    )

    command_id = response["Command"]["CommandId"]
    logger.info("SSM command %s dispatched to %d instance(s).", command_id, len(instance_ids))

    return {
        "status": "remediation_dispatched",
        "alarm": alarm_name,
        "command_id": command_id,
        "instances": instance_ids,
    }
