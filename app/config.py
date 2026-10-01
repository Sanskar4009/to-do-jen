import os
import secrets
from dotenv import load_dotenv

# Load environment variables from .env if present
load_dotenv()


class Config:
    """Application configuration settings."""

    # Flask Core
    FLASK_ENV = os.getenv("FLASK_ENV", "development")
    DEBUG = FLASK_ENV == "development"
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")

    # Server Port
    PORT = int(os.getenv("PORT", 5000))

    # AWS Configuration
    AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
    DYNAMODB_TABLE = os.getenv("DYNAMODB_TABLE", "cloudtodo-tasks")
    SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "").strip()

    # Optional local development endpoint (e.g. LocalStack or DynamoDB Local)
    DYNAMODB_ENDPOINT_URL = os.getenv("DYNAMODB_ENDPOINT_URL", None)


class TestConfig(Config):
    """Testing configuration settings."""

    TESTING = True
    FLASK_ENV = "testing"
    DEBUG = True
    SECRET_KEY = "test-secret-key"
    DYNAMODB_TABLE = "test-cloudtodo-tasks"
    SNS_TOPIC_ARN = "arn:aws:sns:us-east-1:123456789012:test-cloudtodo-notifications"
