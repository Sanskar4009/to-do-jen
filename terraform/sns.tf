# ============================================================
# Amazon SNS Topic & Email Subscription
# ============================================================

resource "aws_sns_topic" "notifications" {
  name = var.sns_topic_name

  tags = {
    Name = var.sns_topic_name
  }
}

# Optional Email Subscription to the SNS Topic
# Note: AWS will dispatch a subscription confirmation email to this address.
# The recipient must click the "Confirm subscription" link in the email before
# notifications will be delivered.
resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
