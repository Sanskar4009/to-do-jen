<#
.SYNOPSIS
    Starts the CloudTodo EC2 instance and displays the permanent Application URL.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $RootDir "terraform"

Set-Location $TerraformDir
$InstanceId = terraform output -raw ec2_instance_id 2>$null
$AppUrl = terraform output -raw application_url 2>$null

if (-not $InstanceId -or $InstanceId -like "*No outputs*") {
    Write-Host "[ERROR] Could not find ec2_instance_id in Terraform outputs." -ForegroundColor Red
    exit 1
}

Write-Host "Starting EC2 instance: $InstanceId..." -ForegroundColor Yellow
aws ec2 start-instances --instance-ids $InstanceId
Write-Host "[OK] Start command issued." -ForegroundColor Green
Write-Host "Your permanent URL: $AppUrl" -ForegroundColor Cyan
Write-Host "Please allow 30-60 seconds for the application container to resume." -ForegroundColor Yellow
