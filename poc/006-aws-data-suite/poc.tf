# S3 Bucket for Data Storage
resource "aws_s3_bucket" "data_bucket" {
  bucket = "my-data-bucket-123123123523234"
  force_destroy = true

  tags = {
    Name        = "DataBucket"
    Environment = "Dev"
  }
}

# Kinesis Data Stream
resource "aws_kinesis_stream" "data_stream" {
  name             = "my-data-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Name        = "DataStream"
    Environment = "Dev"
  }
}

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose_delivery_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "firehose.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Kinesis Firehose to access S3
resource "aws_iam_policy" "firehose_policy" {
  name        = "firehose_policy"
  description = "Policy for Kinesis Firehose to access S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.data_bucket.arn}/*"
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "firehose_attachment" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

# Kinesis Firehose Delivery Stream to S3
resource "aws_kinesis_firehose_delivery_stream" "firehose_to_s3" {
  name        = "my-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.data_bucket.arn

    buffering_size     = 64
    buffering_interval = 300

    compression_format = "GZIP"

    # prefix = "firehose-output/!{partitionKeyFromQuery:event_type}/"

    # dynamic_partitioning_configuration {
    #   enabled = true
    # }
  }

  tags = {
    Name        = "FirehoseToS3"
    Environment = "Dev"
  }
}

# IAM Role for AWS Glue
resource "aws_iam_role" "glue_role" {
  name = "glue_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

# Attach AWS Managed Policy to Glue Role
resource "aws_iam_role_policy_attachment" "glue_policy_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# AWS Glue Catalog Database
resource "aws_glue_catalog_database" "data_catalog" {
  name = "my_data_catalog"
}

# AWS Glue Crawler
resource "aws_glue_crawler" "data_crawler" {
  name          = "my-data-crawler"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.data_catalog.name

  s3_target {
    path = "s3://${aws_s3_bucket.data_bucket.bucket}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
  }

  tags = {
    Name        = "DataCrawler"
    Environment = "Dev"
  }
}

# Athena Workgroup
resource "aws_athena_workgroup" "athena_wg" {
  name = "my_athena_workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.data_bucket.bucket}/athena/results/"
    }
  }

  tags = {
    Name        = "AthenaWorkgroup"
    Environment = "Dev"
  }
}

# Athena Database
resource "aws_athena_database" "athena_db" {
  name   = "my_athena_db"
  bucket = aws_s3_bucket.data_bucket.bucket
}
