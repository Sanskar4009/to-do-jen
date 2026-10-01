# ============================================================
# EC2 Instance & Compute Resources
# ============================================================

# Resolve latest Amazon Linux 2023 AMI if custom AMI ID is not supplied
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# EC2 Instance running Dockerized Flask
resource "aws_instance" "app" {
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.app_profile.name

  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  root_block_device {
    volume_size           = 15
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${local.name_prefix}-root-volume"
    }
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    aws_region         = var.aws_region
    dynamodb_table     = aws_dynamodb_table.tasks.name
    sns_topic_arn      = aws_sns_topic.notifications.arn
    app_repository_url = var.app_repository_url
    app_port           = var.app_port
  })

  user_data_replace_on_change = true

  tags = {
    Name = "${local.name_prefix}-app-server"
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_dynamodb_table.tasks,
    aws_sns_topic.notifications
  ]
}
