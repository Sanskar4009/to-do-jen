#!/bin/bash
# ============================================================
# CloudTodo - Teardown / Destruction Script
# Platform: Linux / macOS (Bash)
# ============================================================

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"

echo -e "${RED}${BOLD}"
echo "============================================================"
echo "    WARNING: CLOUDTODO INFRASTRUCTURE DESTRUCTION"
echo "============================================================"
echo -e "${NC}"

echo -e "${RED}${BOLD}This will delete AWS resources created by Terraform and may cause data loss.${NC}"
echo -e "Resources that will be permanently terminated:"
echo -e "  - AWS EC2 Instance & Root Storage"
echo -e "  - Amazon DynamoDB Table ('cloudtodo-tasks') & ALL stored tasks"
echo -e "  - Amazon SNS Topic & Email Subscriptions"
echo -e "  - Security Groups, Subnets, Route Tables, and VPC"
echo -e "  - IAM Roles and Policies\n"

# 1. Check Terraform
if ! command -v terraform &>/dev/null; then
    echo -e "${RED}[ERROR] Terraform is not installed or not in PATH.${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# 2. Ask for explicit confirmation
echo -e "${YELLOW}To confirm destruction, please type exactly: ${BOLD}destroy${NC}"
read -rp "Confirmation: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo -e "${GREEN}Destruction aborted. No AWS resources were modified.${NC}"
    exit 0
fi

# 3. Execute Terraform Destroy
echo -e "\n${RED}[DELETING] Initiating Terraform destruction across all AWS resources...${NC}"
terraform destroy -auto-approve

echo -e "\n${GREEN}${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}    DESTRUCTION COMPLETE - ALL RESOURCES REMOVED           ${NC}"
echo -e "${GREEN}${BOLD}============================================================${NC}"
