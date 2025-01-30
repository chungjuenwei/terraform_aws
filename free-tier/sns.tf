resource "aws_sns_topic" "test_sns" {
  name = "test-sns-topic"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.test_sns.arn
  protocol  = "email"
  endpoint  = "t21268208+aws_sns_topic@outlook.com"
}
