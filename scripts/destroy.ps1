<#
.SYNOPSIS
    CloudTodo - Teardown / Destruction Script
    Platform: Windows (PowerShell)
#>

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Red
Write-Host "    WARNING: CLOUDTODO INFRASTRUCTURE DESTRUCTION" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "This will delete AWS resources created by Terraform and may cause data loss." -ForegroundColor Red
Write-Host "Resources that will be permanently terminated:" -ForegroundColor Yellow
Write-Host "  - AWS EC2 Instance & Root Storage" -ForegroundColor White
Write-Host "  - Amazon DynamoDB Table ('cloudtodo-tasks') & ALL stored tasks" -ForegroundColor White
Write-Host "  - Amazon SNS Topic & Email Subscriptions" -ForegroundColor White
Write-Host "  - Security Groups, Subnets, Route Tables, and VPC" -ForegroundColor White
Write-Host "  - IAM Roles and Policies" -ForegroundColor White
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $RootDir "terraform"

# 1. Check Terraform
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Terraform is not installed or not in PATH." -ForegroundColor Red
    exit 1
}

Set-Location $TerraformDir

# 2. Ask for explicit confirmation
Write-Host "To confirm destruction, please type exactly: destroy" -ForegroundColor Yellow
$Confirmation = Read-Host "Confirmation"

if ($Confirmation -ne "destroy") {
    Write-Host "Destruction aborted. No AWS resources were modified." -ForegroundColor Green
    exit 0
}

# 3. Execute Terraform Destroy
Write-Host ""
Write-Host "[DELETING] Initiating Terraform destruction across all AWS resources..." -ForegroundColor Red
terraform destroy -auto-approve

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "    DESTRUCTION COMPLETE - ALL RESOURCES REMOVED           " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
