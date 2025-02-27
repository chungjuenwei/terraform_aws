# S3 Bucket for Input Data
resource "aws_s3_bucket" "input_bucket" {
  bucket = "learning-glue-input-2023"  # Ensure this is unique; adjust if needed

  force_destroy = true   # Allows bucket deletion with contents - good when testing
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_input_bucket" {
  bucket = aws_s3_bucket.input_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket for Output Data
resource "aws_s3_bucket" "output_bucket" {
  bucket = "learning-glue-output-2023"  # Ensure this is unique; adjust if needed
  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "glue_output_bucket" {
  bucket = aws_s3_bucket.output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload Sample CSV Data
resource "aws_s3_object" "employees_csv" {
  bucket       = aws_s3_bucket.input_bucket.bucket
  key          = "employees/employees.csv"
  source       = "aws_glue/employees.csv"
  content_type = "text/csv"
}

# Upload ETL Script
resource "aws_s3_object" "etl_script" {
  bucket       = aws_s3_bucket.input_bucket.bucket
  key          = "scripts/etl_script.py"
  source       = "aws_glue/etl_script.py"
  content_type = "application/x-python"
}

# IAM Role for AWS Glue
resource "aws_iam_role" "glue_service_role" {
  name = "learning-glue-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "glue.amazonaws.com" }
      }
    ]
  })
}

# Attach AWSGlueServiceRole Policy
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Inline Policy for S3 Access
resource "aws_iam_role_policy" "s3_access_policy" {
  role = aws_iam_role.glue_service_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.input_bucket.arn, "${aws_s3_bucket.input_bucket.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = [aws_s3_bucket.output_bucket.arn, "${aws_s3_bucket.output_bucket.arn}/*"]
      }
    ]
  })
}

# Glue Catalog Database
resource "aws_glue_catalog_database" "learning_glue_db" {
  name = "learning_glue_db"
}

# Glue Crawler
resource "aws_glue_crawler" "my_crawler" {
  name          = "learning_glue_crawler"
  database_name = aws_glue_catalog_database.learning_glue_db.name
  role          = aws_iam_role.glue_service_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.input_bucket.bucket}/employees/"
  }
}

# # Glue Security Configuration
# resource "aws_glue_security_configuration" "my_security_config" {
#   name = "learning_glue_security_config"

#   encryption_configuration {
#     cloudwatch_encryption { cloudwatch_encryption_mode = "SSE-KMS" }           # Encrypt logs
#     job_bookmarks_encryption { job_bookmarks_encryption_mode = "CSE-KMS" }    # Encrypt bookmarks
#     s3_encryption { s3_encryption_mode = "SSE-KMS" }                          # Encrypt S3 data
#   }
# }

# Glue ETL Job
resource "aws_glue_job" "my_etl_job" {
  name         = "learning_glue_etl_job"
  role_arn     = aws_iam_role.glue_service_role.arn
  glue_version = "2.0"

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.input_bucket.bucket}/scripts/etl_script.py"
  }

  default_arguments = {
    "--job-language" = "python"
    "--output_path"  = "s3://${aws_s3_bucket.output_bucket.bucket}/parquet_data"
  }

  # security_configuration = aws_glue_security_configuration.my_security_config.name
  number_of_workers      = 2    # 2 DPUs for cost-effectiveness
  worker_type            = "G.1X"
}