from unittest.mock import MagicMock, patch
import pytest
from botocore.exceptions import ClientError


@patch("app.dynamodb.get_tasks")
def test_get_index(mock_get_tasks, client):
    """Test GET / returns 200 and renders task list and stats."""
    mock_get_tasks.return_value = [
        {"task_id": "1", "task_name": "Task One", "completed": False, "created_at": "2026-10-02T10:00:00Z", "updated_at": "2026-10-02T10:00:00Z"},
        {"task_id": "2", "task_name": "Task Two", "completed": True, "created_at": "2026-10-02T11:00:00Z", "updated_at": "2026-10-02T11:00:00Z"},
    ]

    response = client.get("/")
    assert response.status_code == 200
    assert b"CloudTodo" in response.data
    assert b"Task One" in response.data
    assert b"Task Two" in response.data
    assert b"2 items" in response.data


@patch("app.dynamodb.get_tasks")
def test_get_index_dynamodb_error(mock_get_tasks, client):
    """Test GET / handles DynamoDB error gracefully without crashing."""
    mock_get_tasks.side_effect = Exception("AWS DynamoDB connection timeout")

    response = client.get("/")
    assert response.status_code == 200
    assert b"Unable to fetch tasks from the database" in response.data


@patch("app.sns_service.notify_task_created")
@patch("app.dynamodb.create_task")
def test_post_add_task_success(mock_create_task, mock_sns, client):
    """Test POST /add creates a task and triggers SNS notification."""
    mock_create_task.return_value = {
        "task_id": "new-uuid-1",
        "task_name": "Setup CI/CD Pipeline",
        "completed": False,
        "created_at": "2026-10-02T12:00:00Z",
    }

    response = client.post("/add", data={"task_name": "Setup CI/CD Pipeline"}, follow_redirects=True)
    assert response.status_code == 200
    assert b"Setup CI/CD Pipeline" in response.data
    mock_create_task.assert_called_once_with("Setup CI/CD Pipeline")
    mock_sns.assert_called_once_with(task_name="Setup CI/CD Pipeline", created_at="2026-10-02T12:00:00Z")


def test_post_add_task_empty_name(client):
    """Test POST /add rejects empty task name."""
    response = client.post("/add", data={"task_name": "   "}, follow_redirects=True)
    assert response.status_code == 200
    assert b"Task name cannot be empty" in response.data


@patch("app.sns_service.notify_task_completed")
@patch("app.dynamodb.toggle_task")
def test_post_toggle_task(mock_toggle, mock_sns, client):
    """Test POST /complete/<task_id> toggles task status."""
    mock_toggle.return_value = {
        "task_id": "uuid-1",
        "task_name": "Configure Terraform",
        "completed": True,
    }

    response = client.post("/complete/uuid-1", follow_redirects=True)
    assert response.status_code == 200
    assert b"marked as completed" in response.data
    mock_toggle.assert_called_once_with("uuid-1")
    mock_sns.assert_called_once_with("Configure Terraform")


@patch("app.dynamodb.get_task")
def test_get_edit_task_found(mock_get_task, client):
    """Test GET /edit/<task_id> renders edit page."""
    mock_get_task.return_value = {
        "task_id": "uuid-1",
        "task_name": "Task to edit",
        "completed": False,
        "created_at": "2026-10-02T10:00:00Z",
        "updated_at": "2026-10-02T10:00:00Z",
    }

    response = client.get("/edit/uuid-1")
    assert response.status_code == 200
    assert b"Edit Task" in response.data
    assert b"Task to edit" in response.data


@patch("app.dynamodb.get_task")
def test_get_edit_task_not_found(mock_get_task, client):
    """Test GET /edit/<task_id> redirects when task does not exist."""
    mock_get_task.return_value = None

    response = client.get("/edit/nonexistent", follow_redirects=True)
    assert response.status_code == 200
    assert b"Task not found." in response.data


@patch("app.sns_service.notify_task_updated")
@patch("app.dynamodb.update_task")
def test_post_edit_task_success(mock_update, mock_sns, client):
    """Test POST /edit/<task_id> updates task and triggers notification."""
    mock_update.return_value = {
        "task_id": "uuid-1",
        "task_name": "Updated Title",
        "completed": False,
    }

    response = client.post("/edit/uuid-1", data={"task_name": "Updated Title"}, follow_redirects=True)
    assert response.status_code == 200
    assert b"Task updated successfully!" in response.data
    mock_update.assert_called_once_with("uuid-1", "Updated Title")
    mock_sns.assert_called_once_with("Updated Title", "Pending")


@patch("app.sns_service.notify_task_deleted")
@patch("app.dynamodb.delete_task")
@patch("app.dynamodb.get_task")
def test_post_delete_task_success(mock_get_task, mock_delete, mock_sns, client):
    """Test POST /delete/<task_id> deletes task and triggers notification."""
    mock_get_task.return_value = {"task_id": "uuid-1", "task_name": "Old Task"}
    mock_delete.return_value = True

    response = client.post("/delete/uuid-1", follow_redirects=True)
    assert response.status_code == 200
    assert b"deleted successfully" in response.data
    mock_delete.assert_called_once_with("uuid-1")
    mock_sns.assert_called_once_with("Old Task")


def test_404_error_page(client):
    """Test accessing non-existent route returns custom 404 page."""
    response = client.get("/this-route-does-not-exist")
    assert response.status_code == 404
    assert b"404" in response.data
    assert b"Page Not Found" in response.data
