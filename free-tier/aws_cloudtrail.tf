data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket_prefix = "my-cloudtrail-bucket-" # Change to a unique bucket name
  force_destroy = true                    # Allows bucket deletion with contents
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_bucket_encryption" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

## LEARNING NOTES
# Ok wait, i didnt understand why this is a data block rather than a resource block
# data "aws_iam_policy_document" "cloudtrail_policy" {
# Is this reading a policy from somewhere? This policy does not need to be created?

# Great question! The data "aws_iam_policy_document" block is not reading an existing policy from AWS. 
# Instead, it is generating a JSON policy document dynamically in Terraform. 
# This is a common pattern in Terraform for creating IAM policies 
# because it allows you to define the policy in a structured way within your code, 
# rather than hardcoding a JSON string.

# To use this method when dynamically creating json policies next time

data "aws_iam_policy_document" "cloudtrail_policy" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_bucket.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/free-tier-cloudtrail"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
      # Add this line for single-region trails
      "${aws_s3_bucket.cloudtrail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/CloudTrail/${data.aws_region.current.name}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/free-tier-cloudtrail"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = data.aws_iam_policy_document.cloudtrail_policy.json
}

resource "aws_cloudtrail" "free_tier_trail" {
  name                          = "free-tier-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  # Management events only (free tier compliant)
  # No data events configured to avoid charges

  # CRITICAL: Add explicit dependency
  depends_on = [aws_s3_bucket_policy.cloudtrail_policy]
}
