variable "aws_region" {
  description = "AWS region for provisioning all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name identifier used for resource naming and tagging"
  type        = string
  default     = "cloudtodo"
}

variable "environment" {
  description = "Target deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Custom AMI ID for EC2. Leave blank to automatically resolve the latest Amazon Linux 2023 AMI"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "AWS EC2 Key Pair name for SSH access (optional, leave blank to disable SSH key attachment)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Target AWS Availability Zone for public subnet and EC2 deployment"
  type        = string
  default     = "us-east-1a"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to establish SSH connections on port 22 (restricted for security)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_repository_url" {
  description = "Public Git repository URL containing the CloudTodo application code for EC2 bootstrapping"
  type        = string
  default     = "https://github.com/YOUR_USERNAME/cloudtodo.git"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for task persistence"
  type        = string
  default     = "cloudtodo-tasks"
}

variable "sns_topic_name" {
  description = "Name of the Amazon SNS topic for task notifications"
  type        = string
  default     = "cloudtodo-notifications"
}

variable "notification_email" {
  description = "Email address subscribed to SNS notifications (requires confirmation via AWS email link)"
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Host port on EC2 mapped to the Flask application container"
  type        = number
  default     = 5000
}
