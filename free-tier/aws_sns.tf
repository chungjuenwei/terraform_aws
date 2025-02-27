# Disabled because i have a billing alerts email
# variable "sns_topic_test_email" {
#   description = "Email for SNS topic demo"
#   type        = string
# }

# resource "aws_sns_topic" "test_sns" {
#   name = "test-sns-topic"
# }

# resource "aws_sns_topic_subscription" "email_sub" {
#   topic_arn = aws_sns_topic.test_sns.arn
#   protocol  = "email"
#   endpoint  = var.sns_topic_test_email
# }
