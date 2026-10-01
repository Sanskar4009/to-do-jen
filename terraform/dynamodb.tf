# ============================================================
# Amazon DynamoDB Table
# On-Demand / Pay-Per-Request Billing Mode
# ============================================================

resource "aws_dynamodb_table" "tasks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}
