# Define variables for flexibility
variable "region" {
  default     = "ap-southeast-1"
  description = "AWS region where resources will be created"
}

variable "app_url" {
  description = "The base URL of your app (e.g., https://myapp.com)"
  default     = "http://localhost:8000"
}

# Configure the AWS provider
provider "aws" {
  region = var.region
}

# Create a Cognito User Pool
resource "aws_cognito_user_pool" "my_pool" {
  name                     = "my-sample-app-pool"
  username_attributes      = ["email"] # Allow users to sign up with email
  auto_verified_attributes = ["email"] # Automatically verify email addresses

  # allows only admins to create users
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

# Create a User Pool Client
resource "aws_cognito_user_pool_client" "my_client" {
  name                                 = "my-sample-app-client"
  user_pool_id                         = aws_cognito_user_pool.my_pool.id
  callback_urls                        = ["${var.app_url}/logged_in.html"]  # Redirect after login
  logout_urls                          = ["${var.app_url}/logged_out.html"] # Redirect after logout
  allowed_oauth_flows                  = ["implicit"]                       # Use implicit grant for simplicity
  allowed_oauth_scopes                 = ["openid", "email", "profile"]     # Scopes for user data
  supported_identity_providers         = ["COGNITO"]                        # Use Cognito as the identity provider
  allowed_oauth_flows_user_pool_client = true
}

# NEW: UI Customization
# resource "aws_cognito_user_pool_ui_customization" "main" {
#   user_pool_id = aws_cognito_user_pool.my_pool.id
#   client_id    = aws_cognito_user_pool_client.my_client.id # Optional: Omit for all clients

#   # Custom CSS
#   css = file("./assets/cognito-ui.css")

#   # Custom Logo (Base64-encoded)
#   image_file = filebase64("./assets/logo.png")
# }

## NOTE THAT YOU CAN CHANGE THE BACKGROUND HERE!!!

# Create a User Pool Domain for the hosted UI
resource "aws_cognito_user_pool_domain" "my_domain" {
  domain       = "my-sample-app" # Must be unique; adjust if necessary
  user_pool_id = aws_cognito_user_pool.my_pool.id
}

# NEW: Create an S3 Bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-sample-app-bucket-unique" # Must be globally unique
}

resource "aws_s3_bucket_cors_configuration" "my_bucket_cors" {
  bucket = aws_s3_bucket.my_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["http://localhost:8000"]
    max_age_seconds = 3000
  }
}

# NEW: Cognito Identity Pool
resource "aws_cognito_identity_pool" "my_identity_pool" {
  identity_pool_name               = "my_sample_app_identity_pool"
  allow_unauthenticated_identities = false # Only authenticated users

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.my_client.id
    provider_name           = aws_cognito_user_pool.my_pool.endpoint
    server_side_token_check = false # Optional, set to false for simplicity
  }
}

# NEW: IAM Role for Authenticated Users
resource "aws_iam_role" "authenticated_role" {
  name = "CognitoAuthenticatedRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.my_identity_pool.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })
}

# NEW: IAM Policy for S3 Read Access
resource "aws_iam_role_policy" "authenticated_s3_policy" {
  name = "S3ReadPolicy"
  role = aws_iam_role.authenticated_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.my_bucket.arn,
          "${aws_s3_bucket.my_bucket.arn}/*"
        ]
      }
    ]
  })
}

# NEW: Attach Role to Identity Pool
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.my_identity_pool.id
  roles = {
    authenticated = aws_iam_role.authenticated_role.arn
  }
}

# Outputs to use in your HTML files
output "user_pool_id" {
  value       = aws_cognito_user_pool.my_pool.id
  description = "The ID of the Cognito User Pool"
}

output "client_id" {
  value       = aws_cognito_user_pool_client.my_client.id
  description = "The Client ID of the User Pool Client"
}

output "domain" {
  value       = aws_cognito_user_pool_domain.my_domain.domain
  description = "The domain prefix for the hosted UI"
}

output "login_url" {
  value       = "https://${aws_cognito_user_pool_domain.my_domain.domain}.auth.${var.region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.my_client.id}&response_type=token&redirect_uri=${var.app_url}/logged_in.html"
  description = "URL for the Register/Login link"
}

output "logout_url" {
  value       = "https://${aws_cognito_user_pool_domain.my_domain.domain}.auth.${var.region}.amazoncognito.com/logout?client_id=${aws_cognito_user_pool_client.my_client.id}&logout_uri=${var.app_url}/logged_out.html"
  description = "URL for the Log Out link"
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.my_identity_pool.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket.bucket
}
