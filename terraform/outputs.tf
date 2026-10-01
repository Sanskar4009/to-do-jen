# ============================================================
# Terraform Infrastructure Outputs
# ============================================================

output "vpc_id" {
  description = "Identifier of the created VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Identifier of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Identifier of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "ec2_instance_id" {
  description = "Instance ID of the provisioned EC2 application server"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "Static Public IPv4 address of the EC2 application server"
  value       = aws_eip.app_eip.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS hostname of the EC2 application server"
  value       = aws_instance.app.public_dns
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB tasks table"
  value       = aws_dynamodb_table.tasks.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB tasks table"
  value       = aws_dynamodb_table.tasks.arn
}

output "sns_topic_name" {
  description = "Name of the created Amazon SNS topic"
  value       = aws_sns_topic.notifications.name
}

output "sns_topic_arn" {
  description = "ARN of the Amazon SNS notification topic"
  value       = aws_sns_topic.notifications.arn
}

output "application_url" {
  description = "Direct web browser URL to access the deployed CloudTodo application"
  value       = "http://${aws_eip.app_eip.public_ip}:${var.app_port}"
}
