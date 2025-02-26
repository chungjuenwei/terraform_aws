# Create a security group for the Redshift cluster
resource "aws_security_group" "redshift_serverless_sg" {
  name        = "redshift-sg"
  description = "Security group for Redshift cluster"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound access on Redshift port (5439, or random redshift port) from your IP only
  ingress {
    description = "Allows incoming Redshift traffic from my public IP"
    from_port   = random_integer.redshift_port.result
    to_port     = random_integer.redshift_port.result
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  # Allow all outbound traffic (default for simplicity)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an IAM role for Redshift to access S3
resource "aws_iam_role" "redshift_serverless_role" {
  name = "redshift-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "redshift.amazonaws.com"
        }
      }
    ]
  })
}

# Custom IAM Policy for S3 Bucket Read-Only Access
resource "aws_iam_policy" "redshift_s3_read_only" {
  name        = "redshift-s3-read-only"
  description = "Read-only access to specific S3 bucket for Redshift Serverless"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.traffic_logs.arn,
          "${aws_s3_bucket.traffic_logs.arn}/*"
        ]
      }
    ]
  })
}

# Attach this policy to this role
resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.redshift_serverless_role.name
  policy_arn = aws_iam_policy.redshift_s3_read_only.arn
}

# # Attach S3 read-only access policy to the IAM role
# resource "aws_iam_role_policy_attachment" "redshift_s3_read" {
#   role       = aws_iam_role.redshift_serverless_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

# Create the Redshift Serverless namespace
resource "aws_redshiftserverless_namespace" "default" {
  namespace_name       = "my-serverless-namespace"
  db_name              = "dev" # Default database name
  admin_username       = "admin"
  admin_user_password  = var.redshift_admin_password
  iam_roles            = [aws_iam_role.redshift_serverless_role.arn]
  default_iam_role_arn = aws_iam_role.redshift_serverless_role.arn
  # kms_key_id          = "aws/redshift"  # Dont need to specify key for encryption
}

variable "redshift_admin_password" {
  description = "Master password for Redshift cluster"
  type        = string
  sensitive   = true
  default     = "adminAdminAMDIMIN123123"
}

## Variable to create workgroup
variable "create_workgroup" {
  description = "Whether to create the Redshift Serverless workgroup"
  type        = bool
  default     = false # put true to create workgroup, false to not create
}


# Generate random SSH port between 40000-49999
resource "random_integer" "redshift_port" {
  min = 40000
  max = 49999
}

# Create the Redshift Serverless workgroup
resource "aws_redshiftserverless_workgroup" "default" {
  count               = var.create_workgroup ? 1 : 0
  workgroup_name      = "my-serverless-workgroup"
  namespace_name      = aws_redshiftserverless_namespace.default.namespace_name
  base_capacity       = 8 # Minimum base RPU (Redshift Processing Units), ~$0.36/hour
  max_capacity        = 8
  publicly_accessible = true # For learning, restricted by security group
  security_group_ids  = [aws_security_group.redshift_serverless_sg.id]
  subnet_ids          = module.vpc.public_subnets
  port                = random_integer.redshift_port.result
}

# To be deleted if it works
# output "aws_redshift_endpoint" {
#   value = "Endpoint: ${aws_redshiftserverless_workgroup.default.endpoint} Port: ${aws_redshiftserverless_workgroup.default.port}"
# }

output "aws_redshift_endpoint" {
  value       = var.create_workgroup ? "Endpoint: ${aws_redshiftserverless_workgroup.default[0].endpoint} Port: ${aws_redshiftserverless_workgroup.default[0].port}" : "Workgroup not provisioned"
  description = "Redshift Serverless workgroup endpoint and port, if provisioned"
}

## Creates an s3 bucket, populates it with data, and then uploads it to s3

# S3 Bucket for Traffic Logs
resource "aws_s3_bucket" "traffic_logs" {
  bucket = "my-traffic-logs-bucket-${random_string.bucket_suffix.result}"
  # Note: Bucket names must be globally unique, so we append a random suffix
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Provision CSV File as a Local File
resource "local_file" "traffic_logs_csv" {
  filename = "${path.module}/aws_redshift/traffic_logs.csv"
  content  = <<EOF
timestamp,page,user_id,ip_address
2025-02-24 08:15:00,/home,user123,192.168.1.1
2025-02-24 08:16:00,/products,user124,192.168.1.2
2025-02-24 09:00:00,/home,user125,192.168.1.3
2025-02-24 10:30:00,/about,user123,192.168.1.1
2025-02-24 12:00:00,/products,user126,192.168.1.4
EOF
}

# Upload CSV to S3
resource "aws_s3_object" "traffic_logs_upload" {
  bucket     = aws_s3_bucket.traffic_logs.id
  key        = "traffic_logs.csv"
  source     = local_file.traffic_logs_csv.filename
  depends_on = [local_file.traffic_logs_csv]
}
















# ============== Possible security hardening configurations
# IAM Role:
# Grants read-only access to S3 for data loading.
# For production, create a custom policy with specific permissions (e.g., s3:GetObject for specific buckets).

# For production, explore IAM database authentication for enhanced security.

# - to provision random port?
