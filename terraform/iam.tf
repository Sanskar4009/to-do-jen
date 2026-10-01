# ============================================================
# IAM Role, Policy, and Instance Profile for EC2
# Implements Least Privilege Access
# ============================================================

# EC2 Assume Role Trust Policy
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Role for EC2
resource "aws_iam_role" "app_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

# Least-Privilege IAM Policy for DynamoDB and SNS access
data "aws_iam_policy_document" "app_permissions" {
  # DynamoDB Operations scoped strictly to the CloudTodo table
  statement {
    sid    = "DynamoDBTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:DescribeTable"
    ]
    resources = [
      aws_dynamodb_table.tasks.arn,
      "${aws_dynamodb_table.tasks.arn}/*"
    ]
  }

  # SNS Operations scoped strictly to the CloudTodo notification topic
  statement {
    sid    = "SNSPublishAccess"
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.notifications.arn
    ]
  }

  # S3 Operations scoped strictly to downloading the application deployment archive
  statement {
    sid    = "S3ArtifactReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.app_artifacts.arn}/*"
    ]
  }
}

# Create IAM Policy
resource "aws_iam_policy" "app_policy" {
  name        = "${local.name_prefix}-app-policy"
  description = "Least-privilege policy for CloudTodo EC2 instance to access DynamoDB and SNS"
  policy      = data.aws_iam_policy_document.app_permissions.json

  tags = {
    Name = "${local.name_prefix}-app-policy"
  }
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "app_attachment" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Attach AWS Systems Manager (SSM) Managed Policy for secure remote management
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance Profile to associate IAM Role with EC2
resource "aws_iam_instance_profile" "app_profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.app_role.name

  tags = {
    Name = "${local.name_prefix}-instance-profile"
  }
}
