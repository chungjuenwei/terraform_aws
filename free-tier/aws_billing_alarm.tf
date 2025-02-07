variable "billing_alerts_email" {
  description = "Email for billing alerts"
  type        = string
}

# Step 1: Create an SNS topic for billing alerts
resource "aws_sns_topic" "billing_alerts" {
  name = "billing-alerts-topic"
}

# Step 2: Subscribe your email to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.billing_alerts.arn
  protocol  = "email"
  endpoint  = var.billing_alerts_email  # Change this to your actual email
}

# Step 3: Create a CloudWatch alarm for AWS billing
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "aws-billing-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace          = "AWS/Billing"
  period             = 86400  # Check every 24 hours
  statistic          = "Maximum"
  threshold         = 0.01  # Alert if cost is more than $0.01 (modify as needed)
  alarm_description  = "Triggers when AWS charges exceed free tier limits."
  alarm_actions      = [aws_sns_topic.billing_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}
