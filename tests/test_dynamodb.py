from unittest.mock import MagicMock, patch
import pytest
from botocore.exceptions import ClientError
from app import dynamodb


@patch("app.dynamodb.get_table")
def test_create_task_success(mock_get_table):
    """Test successful task creation in DynamoDB."""
    mock_table = MagicMock()
    mock_get_table.return_value = mock_table

    task = dynamodb.create_task("Complete Cloud Architecture")

    assert task is not None
    assert task["task_name"] == "Complete Cloud Architecture"
    assert task["completed"] is False
    assert "task_id" in task
    assert "created_at" in task
    assert "updated_at" in task
    mock_table.put_item.assert_called_once_with(Item=task)


def test_create_task_empty_name():
    """Test task creation with empty or whitespace-only name raises ValueError."""
    with pytest.raises(ValueError):
        dynamodb.create_task("   ")


@patch("app.dynamodb.get_table")
def test_get_tasks_success(mock_get_table):
    """Test retrieving tasks from DynamoDB with descending sort order."""
    mock_table = MagicMock()
    mock_table.scan.return_value = {
        "Items": [
            {"task_id": "1", "task_name": "Task 1", "created_at": "2026-10-01T10:00:00Z"},
            {"task_id": "2", "task_name": "Task 2", "created_at": "2026-10-02T10:00:00Z"},
        ]
    }
    mock_get_table.return_value = mock_table

    tasks = dynamodb.get_tasks()
    assert len(tasks) == 2
    # Verify descending sort: newest task (Task 2) comes first
    assert tasks[0]["task_id"] == "2"
    assert tasks[1]["task_id"] == "1"


@patch("app.dynamodb.get_table")
def test_get_task_found(mock_get_table):
    """Test retrieving an existing task by ID."""
    mock_table = MagicMock()
    mock_table.get_item.return_value = {
        "Item": {"task_id": "uuid-123", "task_name": "Deploy Terraform", "completed": False}
    }
    mock_get_table.return_value = mock_table

    task = dynamodb.get_task("uuid-123")
    assert task is not None
    assert task["task_name"] == "Deploy Terraform"


@patch("app.dynamodb.get_table")
def test_get_task_not_found(mock_get_table):
    """Test retrieving a non-existent task returns None."""
    mock_table = MagicMock()
    mock_table.get_item.return_value = {}
    mock_get_table.return_value = mock_table

    task = dynamodb.get_task("nonexistent-id")
    assert task is None


@patch("app.dynamodb.get_table")
def test_update_task_success(mock_get_table):
    """Test updating task name successfully."""
    mock_table = MagicMock()
    mock_table.update_item.return_value = {
        "Attributes": {
            "task_id": "uuid-123",
            "task_name": "Updated Task Name",
            "completed": False,
            "updated_at": "2026-10-02T12:00:00Z",
        }
    }
    mock_get_table.return_value = mock_table

    updated = dynamodb.update_task("uuid-123", "Updated Task Name")
    assert updated is not None
    assert updated["task_name"] == "Updated Task Name"
    mock_table.update_item.assert_called_once()


@patch("app.dynamodb.get_table")
def test_update_task_not_found(mock_get_table):
    """Test update returns None when conditional check fails (task not found)."""
    mock_table = MagicMock()
    error_response = {"Error": {"Code": "ConditionalCheckFailedException", "Message": "Task not found"}}
    mock_table.update_item.side_effect = ClientError(error_response, "UpdateItem")
    mock_get_table.return_value = mock_table

    result = dynamodb.update_task("missing-id", "New Name")
    assert result is None


@patch("app.dynamodb.get_task")
@patch("app.dynamodb.get_table")
def test_toggle_task_success(mock_get_table, mock_get_task):
    """Test toggling task completion status from pending to completed."""
    mock_get_task.return_value = {
        "task_id": "uuid-123",
        "task_name": "Write unit tests",
        "completed": False,
    }
    mock_table = MagicMock()
    mock_table.update_item.return_value = {
        "Attributes": {
            "task_id": "uuid-123",
            "task_name": "Write unit tests",
            "completed": True,
        }
    }
    mock_get_table.return_value = mock_table

    toggled = dynamodb.toggle_task("uuid-123")
    assert toggled is not None
    assert toggled["completed"] is True


@patch("app.dynamodb.get_table")
def test_delete_task_success(mock_get_table):
    """Test deleting task from DynamoDB."""
    mock_table = MagicMock()
    mock_table.delete_item.return_value = {}
    mock_get_table.return_value = mock_table

    result = dynamodb.delete_task("uuid-123")
    assert result is True
    mock_table.delete_item.assert_called_once()


@patch("app.dynamodb.get_table")
def test_delete_task_not_found(mock_get_table):
    """Test delete returns False when task does not exist."""
    mock_table = MagicMock()
    error_response = {"Error": {"Code": "ConditionalCheckFailedException", "Message": "Task does not exist"}}
    mock_table.delete_item.side_effect = ClientError(error_response, "DeleteItem")
    mock_get_table.return_value = mock_table

    result = dynamodb.delete_task("missing-uuid")
    assert result is False
