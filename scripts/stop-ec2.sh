#!/bin/bash
# ============================================================
# CloudTodo - Stop EC2 Instance (Pause Compute Billing)
# Platform: Linux / macOS (Bash)
# ============================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"

cd "$TERRAFORM_DIR"
INSTANCE_ID=$(terraform output -raw ec2_instance_id 2>/dev/null || true)

if [ -z "$INSTANCE_ID" ] || [[ "$INSTANCE_ID" == *"No outputs"* ]]; then
    echo "[ERROR] Could not find ec2_instance_id in Terraform outputs."
    exit 1
fi

echo "Stopping EC2 instance: $INSTANCE_ID to pause compute billing..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
echo "[OK] Stop command issued. Compute billing paused."
echo "Your Elastic IP is preserved. To restart anytime, run: ./scripts/start-ec2.sh"
