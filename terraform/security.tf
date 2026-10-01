# ============================================================
# Security Groups & Firewall Rules
# ============================================================

resource "aws_security_group" "ec2_sg" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for CloudTodo EC2 instance hosting Dockerized Flask"
  vpc_id      = aws_vpc.main.id

  # Application Ingress (Default: Port 5000)
  ingress {
    description = "Flask Web Application Port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard HTTP Ingress
  ingress {
    description = "Standard HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard HTTPS Ingress
  ingress {
    description = "Standard HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Restricted SSH Ingress
  ingress {
    description = "Administrative SSH Access (Restricted CIDR)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Outbound Egress (Permit all outbound for updates, AWS APIs, and Docker Hub)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ec2-sg"
  }
}
