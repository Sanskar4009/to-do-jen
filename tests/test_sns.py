import os
from unittest.mock import MagicMock, patch
import pytest
from botocore.exceptions import ClientError
from app import sns_service


@patch("app.sns_service.get_sns_client")
def test_publish_notification_success(mock_get_client):
    """Test successful SNS notification publishing."""
    mock_client = MagicMock()
    mock_client.publish.return_value = {"MessageId": "msg-uuid-9999"}
    mock_get_client.return_value = mock_client

    with patch.dict(os.environ, {"SNS_TOPIC_ARN": "arn:aws:sns:us-east-1:123456789012:test-topic"}):
        msg_id = sns_service.publish_notification("Test Subject", "Test Body")

    assert msg_id == "msg-uuid-9999"
    mock_client.publish.assert_called_once_with(
        TopicArn="arn:aws:sns:us-east-1:123456789012:test-topic",
        Subject="Test Subject",
        Message="Test Body",
    )


@patch("app.sns_service.get_sns_client")
def test_publish_notification_no_topic_arn(mock_get_client):
    """Test SNS publish skips gracefully when SNS_TOPIC_ARN is empty."""
    with patch.dict(os.environ, {"SNS_TOPIC_ARN": ""}):
        result = sns_service.publish_notification("Subject", "Body")

    assert result is None
    mock_get_client.assert_not_called()


@patch("app.sns_service.get_sns_client")
def test_publish_notification_client_error_does_not_crash(mock_get_client):
    """Test SNS publish handles ClientError gracefully without raising exception."""
    mock_client = MagicMock()
    error_response = {"Error": {"Code": "NotFound", "Message": "Topic does not exist"}}
    mock_client.publish.side_effect = ClientError(error_response, "Publish")
    mock_get_client.return_value = mock_client

    with patch.dict(os.environ, {"SNS_TOPIC_ARN": "arn:aws:sns:us-east-1:123456789012:invalid-topic"}):
        result = sns_service.publish_notification("Test Subject", "Test Body")

    assert result is None


@patch("app.sns_service.publish_notification")
def test_notify_task_created(mock_publish):
    """Test notify_task_created format and subject."""
    mock_publish.return_value = "msg-1"
    sns_service.notify_task_created("Learn Terraform", "2026-10-02T12:00:00Z")

    mock_publish.assert_called_once()
    args, kwargs = mock_publish.call_args
    assert kwargs["subject"] == "CloudTodo - New Task Created"
    assert "Learn Terraform" in kwargs["message"]
    assert "Pending" in kwargs["message"]
    assert "2026-10-02T12:00:00Z" in kwargs["message"]


@patch("app.sns_service.publish_notification")
def test_notify_task_completed(mock_publish):
    """Test notify_task_completed format and subject."""
    mock_publish.return_value = "msg-2"
    sns_service.notify_task_completed("Learn Terraform")

    mock_publish.assert_called_once()
    args, kwargs = mock_publish.call_args
    assert kwargs["subject"] == "CloudTodo - Task Completed"
    assert "Learn Terraform" in kwargs["message"]
    assert "Completed" in kwargs["message"]


@patch("app.sns_service.publish_notification")
def test_notify_task_reopened(mock_publish):
    """Test notify_task_reopened format and subject."""
    mock_publish.return_value = "msg-3"
    sns_service.notify_task_reopened("Learn Terraform")

    mock_publish.assert_called_once()
    args, kwargs = mock_publish.call_args
    assert kwargs["subject"] == "CloudTodo - Task Reopened"
    assert "Learn Terraform" in kwargs["message"]
    assert "Pending" in kwargs["message"]


@patch("app.sns_service.publish_notification")
def test_notify_task_updated(mock_publish):
    """Test notify_task_updated format and subject."""
    mock_publish.return_value = "msg-4"
    sns_service.notify_task_updated("Learn Terraform 2.0", "Pending")

    mock_publish.assert_called_once()
    args, kwargs = mock_publish.call_args
    assert kwargs["subject"] == "CloudTodo - Task Updated"
    assert "Learn Terraform 2.0" in kwargs["message"]
    assert "Pending" in kwargs["message"]


@patch("app.sns_service.publish_notification")
def test_notify_task_deleted(mock_publish):
    """Test notify_task_deleted format and subject."""
    mock_publish.return_value = "msg-5"
    sns_service.notify_task_deleted("Learn Terraform")

    mock_publish.assert_called_once()
    args, kwargs = mock_publish.call_args
    assert kwargs["subject"] == "CloudTodo - Task Deleted"
    assert "Learn Terraform" in kwargs["message"]
