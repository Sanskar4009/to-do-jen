#!/bin/bash
# ============================================================
# CloudTodo - Automated AWS Infrastructure & App Deployment Script
# Platform: Linux / macOS (Bash)
# ============================================================

set -euo pipefail

# ANSI Color Codes
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/terraform"

echo -e "${CYAN}${BOLD}"
echo "============================================================"
echo "    CloudTodo - Automated AWS Deployment Pipeline"
echo "============================================================"
echo -e "${NC}"

# 1. Check Terraform is installed
echo -e "${BOLD}[1/10] Verifying Terraform installation...${NC}"
if ! command -v terraform &>/dev/null; then
    echo -e "${RED}[ERROR] Terraform is not installed or not in PATH.${NC}"
    echo "Please install Terraform from: https://developer.hashicorp.com/terraform/install"
    exit 1
fi
TF_VERSION=$(terraform -version | head -n 1)
echo -e "${GREEN}✓ Found: ${TF_VERSION}${NC}"

# 2. Check AWS CLI is installed
echo -e "\n${BOLD}[2/10] Verifying AWS CLI installation...${NC}"
if ! command -v aws &>/dev/null; then
    echo -e "${RED}[ERROR] AWS CLI is not installed or not in PATH.${NC}"
    echo "Please install AWS CLI from: https://aws.amazon.com/cli/"
    exit 1
fi
AWS_VERSION=$(aws --version | head -n 1)
echo -e "${GREEN}✓ Found: ${AWS_VERSION}${NC}"

# 3. Check AWS Authentication
echo -e "\n${BOLD}[3/10] Verifying AWS credentials and authentication...${NC}"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Unable to authenticate with AWS.${NC}"
    echo "Please run 'aws configure' or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY."
    exit 1
fi
AWS_IDENTITY=$(aws sts get-caller-identity --output text --query '[Account,Arn]')
echo -e "${GREEN}✓ Authenticated as: ${AWS_IDENTITY}${NC}"

# 4. Check configuration variables (terraform.tfvars)
echo -e "\n${BOLD}[4/10] Checking deployment configuration (terraform.tfvars)...${NC}"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
TFVARS_EXAMPLE="$TERRAFORM_DIR/terraform.tfvars.example"

if [ ! -f "$TFVARS_FILE" ]; then
    echo -e "${YELLOW}[WARNING] Configuration file '$TFVARS_FILE' not found!${NC}"
    echo -e "Creating 'terraform.tfvars' from '$TFVARS_EXAMPLE'..."
    cp "$TFVARS_EXAMPLE" "$TFVARS_FILE"
    echo -e "${GREEN}✓ Created: $TFVARS_FILE${NC}"
    echo -e "${YELLOW}Please review and customize $TFVARS_FILE (especially notification_email and app_repository_url) if desired.${NC}"
else
    echo -e "${GREEN}✓ Found configuration file: $TFVARS_FILE${NC}"
fi

cd "$TERRAFORM_DIR"

# 5. Run Terraform Init
echo -e "\n${BOLD}[5/10] Initializing Terraform working directory...${NC}"
terraform init -upgrade

# 6. Run Terraform Format
echo -e "\n${BOLD}[6/10] Checking Terraform formatting...${NC}"
terraform fmt

# 7. Run Terraform Validate
echo -e "\n${BOLD}[7/10] Validating Terraform configuration syntax...${NC}"
terraform validate

# 8. Run Terraform Plan
echo -e "\n${BOLD}[8/10] Generating Terraform execution plan...${NC}"
terraform plan -out=tfplan

# 9. Ask for confirmation
echo -e "\n${BOLD}[9/10] User Confirmation${NC}"
echo -e "${YELLOW}Review the execution plan above.${NC}"
read -rp "Are you ready to provision these AWS resources? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" && "$CONFIRM" != "y" ]]; then
    echo -e "${YELLOW}Deployment cancelled by user. Cleaning up plan file.${NC}"
    rm -f tfplan
    exit 0
fi

# 10. Run Terraform Apply
echo -e "\n${BOLD}[10/10] Applying Terraform plan to AWS...${NC}"
terraform apply tfplan
rm -f tfplan

# 11. Display deployment summary and outputs
echo -e "\n${GREEN}${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}    DEPLOYMENT COMPLETE - CLOUDTODO IS LIVE!               ${NC}"
echo -e "${GREEN}${BOLD}============================================================${NC}\n"

APP_URL=$(terraform output -raw application_url 2>/dev/null || echo "N/A")
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "N/A")
DYNAMO_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "N/A")
SNS_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null || echo "N/A")

echo -e "${BOLD}Application URL:${NC}    ${CYAN}${APP_URL}${NC}"
echo -e "${BOLD}EC2 Public IP:${NC}      ${EC2_IP}"
echo -e "${BOLD}DynamoDB Table:${NC}     ${DYNAMO_TABLE}"
echo -e "${BOLD}SNS Topic ARN:${NC}      ${SNS_ARN}"
echo ""
echo -e "${YELLOW}${BOLD}IMPORTANT - NEXT STEPS:${NC}"
echo -e "1. If you configured an email in terraform.tfvars, AWS has sent a confirmation email."
echo -e "   You MUST click the 'Confirm subscription' link in your email inbox to receive task alerts."
echo -e "2. EC2 user_data takes approximately 1-2 minutes to install Docker and start the container."
echo -e "   If the URL is not immediately reachable, wait 60-90 seconds and refresh."
echo -e "3. To destroy this infrastructure when done, run: ./scripts/destroy.sh"
echo -e "${GREEN}============================================================${NC}"
