<#
.SYNOPSIS
    Stops the CloudTodo EC2 instance to pause compute costs.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$TerraformDir = Join-Path $RootDir "terraform"

Set-Location $TerraformDir
$InstanceId = terraform output -raw ec2_instance_id 2>$null

if (-not $InstanceId -or $InstanceId -like "*No outputs*") {
    Write-Host "[ERROR] Could not find ec2_instance_id in Terraform outputs." -ForegroundColor Red
    exit 1
}

Write-Host "Stopping EC2 instance: $InstanceId to pause compute costs..." -ForegroundColor Yellow
aws ec2 stop-instances --instance-ids $InstanceId
Write-Host "[OK] Stop command issued. Compute billing paused." -ForegroundColor Green
Write-Host "To restart anytime, run: .\scripts\start-ec2.ps1" -ForegroundColor Cyan
