import logging
import os
from typing import Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


def get_sns_client():
    """Create and return a boto3 SNS client using environment configuration."""
    region = os.getenv("AWS_REGION", "us-east-1")
    return boto3.client("sns", region_name=region)


def publish_notification(subject: str, message: str) -> Optional[str]:
    """Publish a notification message to the configured AWS SNS Topic.

    IMPORTANT ERROR HANDLING:
    If SNS publish fails for any reason (missing ARN, network issue, AWS permissions),
    the failure is logged, but an exception is NOT raised. This ensures that
    successful DynamoDB operations never fail due to notification delivery issues.

    Args:
        subject: The email subject (max 100 ASCII chars as per SNS specs).
        message: The email message body.

    Returns:
        MessageId string if published successfully, None otherwise.
    """
    topic_arn = os.getenv("SNS_TOPIC_ARN", "").strip()

    if not topic_arn:
        logger.info("SNS_TOPIC_ARN is not configured; skipping notification.")
        return None

    try:
        sns_client = get_sns_client()
        # Truncate subject to 100 characters if longer (SNS Subject constraint)
        safe_subject = subject[:100]
        response = sns_client.publish(
            TopicArn=topic_arn,
            Subject=safe_subject,
            Message=message,
        )
        message_id = response.get("MessageId")
        logger.info("SNS notification published successfully. MessageId: %s | Subject: %s", message_id, safe_subject)
        return message_id
    except ClientError as e:
        logger.error(
            "AWS SNS ClientError while publishing notification: %s (TopicArn: %s)",
            e.response.get("Error", {}).get("Message", str(e)),
            topic_arn,
        )
        return None
    except Exception as e:
        logger.error("Unexpected error publishing to SNS: %s", str(e))
        return None


# ============================================================
# EVENT-SPECIFIC NOTIFICATION HELPERS
# ============================================================

def notify_task_created(task_name: str, created_at: str) -> Optional[str]:
    """Send notification when a new task is created."""
    subject = "CloudTodo - New Task Created"
    message = (
        "A new task has been created.\n\n"
        f"Task:\n{task_name}\n\n"
        "Status:\nPending\n\n"
        f"Created:\n{created_at}"
    )
    return publish_notification(subject=subject, message=message)


def notify_task_completed(task_name: str) -> Optional[str]:
    """Send notification when a task is completed."""
    subject = "CloudTodo - Task Completed"
    message = (
        "A task has been completed.\n\n"
        f"Task:\n{task_name}\n\n"
        "Status:\nCompleted"
    )
    return publish_notification(subject=subject, message=message)


def notify_task_reopened(task_name: str) -> Optional[str]:
    """Send notification when a completed task is moved back to pending."""
    subject = "CloudTodo - Task Reopened"
    message = (
        "A task has been moved back to pending.\n\n"
        f"Task:\n{task_name}\n\n"
        "Status:\nPending"
    )
    return publish_notification(subject=subject, message=message)


def notify_task_updated(task_name: str, status: str) -> Optional[str]:
    """Send notification when a task's name or details are updated."""
    subject = "CloudTodo - Task Updated"
    message = (
        "A task has been updated.\n\n"
        f"Task:\n{task_name}\n\n"
        f"Status:\n{status}"
    )
    return publish_notification(subject=subject, message=message)


def notify_task_deleted(task_name: str) -> Optional[str]:
    """Send notification when a task is deleted."""
    subject = "CloudTodo - Task Deleted"
    message = (
        "A task has been deleted.\n\n"
        f"Task:\n{task_name}"
    )
    return publish_notification(subject=subject, message=message)
