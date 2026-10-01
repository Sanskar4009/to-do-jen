import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)


def get_dynamodb_resource():
    """Create and return a boto3 DynamoDB resource using environment configuration.

    Boto3 automatically resolves credentials from:
    1. EC2 Instance Profile (IAM Role) in production
    2. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    3. AWS CLI configuration (~/.aws/credentials) in local dev
    """
    region = os.getenv("AWS_REGION", "us-east-1")
    endpoint_url = os.getenv("DYNAMODB_ENDPOINT_URL", None)

    params: Dict[str, Any] = {"region_name": region}
    if endpoint_url:
        params["endpoint_url"] = endpoint_url

    return boto3.resource("dynamodb", **params)


def get_table():
    """Get the DynamoDB Table resource."""
    table_name = os.getenv("DYNAMODB_TABLE", "cloudtodo-tasks")
    dynamodb = get_dynamodb_resource()
    return dynamodb.Table(table_name)


def create_task(task_name: str) -> Optional[Dict[str, Any]]:
    """Create a new task in DynamoDB.

    Args:
        task_name: The name/description of the task.

    Returns:
        The created task dictionary or None on failure.
    """
    cleaned_name = task_name.strip()
    if not cleaned_name:
        raise ValueError("Task name cannot be empty")

    now = datetime.now(timezone.utc).isoformat()
    task_id = str(uuid.uuid4())

    item = {
        "task_id": task_id,
        "task_name": cleaned_name,
        "completed": False,
        "created_at": now,
        "updated_at": now,
    }

    try:
        table = get_table()
        table.put_item(Item=item)
        logger.info("Task created successfully with ID: %s", task_id)
        return item
    except ClientError as e:
        logger.error("DynamoDB ClientError while creating task: %s", e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error creating task in DynamoDB: %s", str(e))
        raise


def get_tasks() -> List[Dict[str, Any]]:
    """Retrieve all tasks from DynamoDB.

    Returns:
        List of task dictionaries sorted by creation time (newest first).
    """
    try:
        table = get_table()
        response = table.scan()
        items = response.get("Items", [])

        # Handle pagination if table has more than 1MB of data
        while "LastEvaluatedKey" in response:
            response = table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
            items.extend(response.get("Items", []))

        # Sort tasks by created_at descending
        items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
        return items
    except ClientError as e:
        logger.error("DynamoDB ClientError while fetching tasks: %s", e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error fetching tasks from DynamoDB: %s", str(e))
        raise


def get_task(task_id: str) -> Optional[Dict[str, Any]]:
    """Retrieve a single task by its task_id.

    Args:
        task_id: UUID of the task.

    Returns:
        Task dictionary if found, None otherwise.
    """
    if not task_id:
        return None

    try:
        table = get_table()
        response = table.get_item(Key={"task_id": task_id})
        return response.get("Item")
    except ClientError as e:
        logger.error("DynamoDB ClientError while fetching task %s: %s", task_id, e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error fetching task %s: %s", task_id, str(e))
        raise


def update_task(task_id: str, task_name: str) -> Optional[Dict[str, Any]]:
    """Update task_name and updated_at for an existing task.

    Args:
        task_id: UUID of the task.
        task_name: New task name.

    Returns:
        Updated task dictionary or None if task doesn't exist.
    """
    cleaned_name = task_name.strip()
    if not cleaned_name:
        raise ValueError("Task name cannot be empty")

    now = datetime.now(timezone.utc).isoformat()

    try:
        table = get_table()
        response = table.update_item(
            Key={"task_id": task_id},
            UpdateExpression="SET task_name = :val, updated_at = :now",
            ConditionExpression="attribute_exists(task_id)",
            ExpressionAttributeValues={
                ":val": cleaned_name,
                ":now": now,
            },
            ReturnValues="ALL_NEW",
        )
        logger.info("Task %s updated successfully", task_id)
        return response.get("Attributes")
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "ConditionalCheckFailedException":
            logger.warning("Task %s not found for update", task_id)
            return None
        logger.error("DynamoDB ClientError updating task %s: %s", task_id, e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error updating task %s: %s", task_id, str(e))
        raise


def toggle_task(task_id: str) -> Optional[Dict[str, Any]]:
    """Toggle completed status of a task between True and False.

    Args:
        task_id: UUID of the task.

    Returns:
        Updated task dictionary or None if task does not exist.
    """
    try:
        # First retrieve task to determine current status
        current_task = get_task(task_id)
        if not current_task:
            logger.warning("Task %s not found to toggle", task_id)
            return None

        new_status = not bool(current_task.get("completed", False))
        now = datetime.now(timezone.utc).isoformat()

        table = get_table()
        response = table.update_item(
            Key={"task_id": task_id},
            UpdateExpression="SET completed = :status, updated_at = :now",
            ConditionExpression="attribute_exists(task_id)",
            ExpressionAttributeValues={
                ":status": new_status,
                ":now": now,
            },
            ReturnValues="ALL_NEW",
        )
        logger.info("Task %s toggled to completed=%s", task_id, new_status)
        return response.get("Attributes")
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "ConditionalCheckFailedException":
            logger.warning("Task %s not found for toggle", task_id)
            return None
        logger.error("DynamoDB ClientError toggling task %s: %s", task_id, e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error toggling task %s: %s", task_id, str(e))
        raise


def delete_task(task_id: str) -> bool:
    """Delete a task from DynamoDB.

    Args:
        task_id: UUID of the task.

    Returns:
        True if operation completed, False if not found.
    """
    if not task_id:
        return False

    try:
        table = get_table()
        table.delete_item(
            Key={"task_id": task_id},
            ConditionExpression="attribute_exists(task_id)",
        )
        logger.info("Task %s deleted successfully from DynamoDB", task_id)
        return True
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "ConditionalCheckFailedException":
            logger.warning("Task %s not found for deletion", task_id)
            return False
        logger.error("DynamoDB ClientError deleting task %s: %s", task_id, e.response.get("Error", {}).get("Message", str(e)))
        raise
    except Exception as e:
        logger.error("Unexpected error deleting task %s: %s", task_id, str(e))
        raise
