#!/bin/bash
# ============================================================
# CloudTodo - Start EC2 Instance (Resume Application)
# Platform: Linux / macOS (Bash)
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"

cd "$TERRAFORM_DIR"
INSTANCE_ID=$(terraform output -raw ec2_instance_id 2>/dev/null || true)
APP_URL=$(terraform output -raw application_url 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [[ "$INSTANCE_ID" == *"No outputs"* ]]; then
    echo "[ERROR] Could not find ec2_instance_id in Terraform outputs."
    exit 1
fi

echo "Starting EC2 instance: $INSTANCE_ID..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
echo "[OK] Start command issued."
echo "Your permanent URL: $APP_URL"
echo "Please allow 30-60 seconds for the application container to resume."
