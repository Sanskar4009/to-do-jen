<#
.SYNOPSIS
    CloudTodo - Automated AWS Infrastructure & App Deployment Script
    Platform: Windows (PowerShell)
#>

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "    CloudTodo - Automated AWS Deployment Pipeline (PowerShell)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $RootDir "terraform"

# 1. Check Terraform
Write-Host "[1/10] Verifying Terraform installation..." -ForegroundColor Yellow
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Terraform is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Terraform from: https://developer.hashicorp.com/terraform/install" -ForegroundColor White
    exit 1
}
$TfVer = terraform -version | Select-Object -First 1
Write-Host "✓ Found: $TfVer" -ForegroundColor Green

# 2. Check AWS CLI
Write-Host ""
Write-Host "[2/10] Verifying AWS CLI installation..." -ForegroundColor Yellow
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] AWS CLI is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor White
    exit 1
}
$AwsVer = aws --version | Select-Object -First 1
Write-Host "✓ Found: $AwsVer" -ForegroundColor Green

# 3. Check AWS Authentication
Write-Host ""
Write-Host "[3/10] Verifying AWS credentials and authentication..." -ForegroundColor Yellow
try {
    $Identity = aws sts get-caller-identity --output text --query '[Account,Arn]'
    Write-Host "✓ Authenticated as: $Identity" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Unable to authenticate with AWS." -ForegroundColor Red
    Write-Host "Please run 'aws configure' or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY." -ForegroundColor White
    exit 1
}

# 4. Check configuration variables (terraform.tfvars)
Write-Host ""
Write-Host "[4/10] Checking deployment configuration (terraform.tfvars)..." -ForegroundColor Yellow
$TfVarsFile = Join-Path $TerraformDir "terraform.tfvars"
$TfVarsExample = Join-Path $TerraformDir "terraform.tfvars.example"

if (-not (Test-Path $TfVarsFile)) {
    Write-Host "[WARNING] Configuration file '$TfVarsFile' not found!" -ForegroundColor Yellow
    Write-Host "Creating 'terraform.tfvars' from '$TfVarsExample'..." -ForegroundColor White
    Copy-Item $TfVarsExample $TfVarsFile
    Write-Host "✓ Created: $TfVarsFile" -ForegroundColor Green
    Write-Host "Please review and customize $TfVarsFile (especially notification_email and app_repository_url) if desired." -ForegroundColor Yellow
} else {
    Write-Host "✓ Found configuration file: $TfVarsFile" -ForegroundColor Green
}

Set-Location $TerraformDir

# 5. Run Terraform Init
Write-Host ""
Write-Host "[5/10] Initializing Terraform working directory..." -ForegroundColor Yellow
terraform init -upgrade

# 6. Run Terraform Format
Write-Host ""
Write-Host "[6/10] Checking Terraform formatting..." -ForegroundColor Yellow
terraform fmt

# 7. Run Terraform Validate
Write-Host ""
Write-Host "[7/10] Validating Terraform configuration syntax..." -ForegroundColor Yellow
terraform validate

# 8. Run Terraform Plan
Write-Host ""
Write-Host "[8/10] Generating Terraform execution plan..." -ForegroundColor Yellow
terraform plan -out=tfplan

# 9. Ask for Confirmation
Write-Host ""
Write-Host "[9/10] User Confirmation" -ForegroundColor Yellow
Write-Host "Review the execution plan above." -ForegroundColor White
$Confirmation = Read-Host "Are you ready to provision these AWS resources? (yes/no)"
if ($Confirmation -ne "yes" -and $Confirmation -ne "y") {
    Write-Host "Deployment cancelled by user. Cleaning up plan file." -ForegroundColor Yellow
    if (Test-Path "tfplan") { Remove-Item "tfplan" }
    exit 0
}

# 10. Run Terraform Apply
Write-Host ""
Write-Host "[10/10] Applying Terraform plan to AWS..." -ForegroundColor Yellow
terraform apply tfplan
if (Test-Path "tfplan") { Remove-Item "tfplan" }

# Display Summary
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "    DEPLOYMENT COMPLETE - CLOUDTODO IS LIVE!               " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

$AppUrl = terraform output -raw application_url
$Ec2Ip = terraform output -raw ec2_public_ip
$DynamoTable = terraform output -raw dynamodb_table_name
$SnsArn = terraform output -raw sns_topic_arn

Write-Host "Application URL: $AppUrl" -ForegroundColor Cyan
Write-Host "EC2 Public IP:   $Ec2Ip" -ForegroundColor White
Write-Host "DynamoDB Table:  $DynamoTable" -ForegroundColor White
Write-Host "SNS Topic ARN:   $SnsArn" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT - NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. If you configured an email in terraform.tfvars, AWS has sent a confirmation email." -ForegroundColor White
Write-Host "   You MUST click the 'Confirm subscription' link in your email inbox to receive alerts." -ForegroundColor White
Write-Host "2. EC2 user_data takes approximately 1-2 minutes to install Docker and start the container." -ForegroundColor White
Write-Host "   If the URL is not immediately reachable, wait 60-90 seconds and refresh." -ForegroundColor White
Write-Host "3. To destroy this infrastructure when done, run: .\scripts\destroy.ps1" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green
