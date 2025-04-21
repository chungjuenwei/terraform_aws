# Cognito User Pool
resource "aws_cognito_user_pool" "linkace_pool" {
  name = "linkace-pool"

  # Basic settings (customize as needed)
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  # Auto-verify email (optional, simplifies user setup)
  auto_verified_attributes = ["email"]

  # Schema for email (required for OIDC)
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
}

# Cognito App Client (for LinkAce)
resource "aws_cognito_user_pool_client" "linkace_client" {
  name                = "linkace-app"
  user_pool_id        = aws_cognito_user_pool.linkace_pool.id
  generate_secret     = false # No client secret for simplicity
  callback_urls       = ["http://localhost:8080/auth/oidc/callback"] # Adjust to your LinkAce URL
  allowed_oauth_flows = ["code"] # Authorization code grant
  allowed_oauth_scopes = ["openid", "email", "profile"]
  supported_identity_providers = ["COGNITO"]

  # Token validity (optional, adjust as needed)
  refresh_token_validity = 30 # Days
  access_token_validity  = 1  # Hours
  id_token_validity      = 1  # Hours
}

# Cognito Domain
resource "aws_cognito_user_pool_domain" "linkace_domain" {
  domain       = "linkace-auth" # Must be unique across AWS, adjust if needed
  user_pool_id = aws_cognito_user_pool.linkace_pool.id
}

# Outputs for LinkAce configuration
output "client_id" {
  value = aws_cognito_user_pool_client.linkace_client.id
}

# output "issuer_url" {
#   value = "https://cognito-idp.${aws_cognito_user_pool.linkace_pool.}.amazonaws.com/${aws_cognito_user_pool.linkace_pool.id}"
# }

# output "authorization_endpoint" {
#   value = "https://${aws_cognito_user_pool_domain.linkace_domain.domain}.auth.${aws_cognito_user_pool.linkace_pool.region}.amazoncognito.com/oauth2/authorize"
# }

# output "token_endpoint" {
#   value = "https://${aws_cognito_user_pool_domain.linkace_domain.domain}.auth.${aws_cognito_user_pool.linkace_pool.region}.amazoncognito.com/oauth2/token"
# }

# output "userinfo_endpoint" {
#   value = "https://${aws_cognito_user_pool_domain.linkace_domain.domain}.auth.${aws_cognito_user_pool.linkace_pool.region}.amazoncognito.com/oauth2/userInfo"
# }