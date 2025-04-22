terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.84.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"   # Fixed version for Random provider
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.6"
    }
    http = {
      source = "hashicorp/http"
      version = "3.4.5"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"

  # This is to force the s3 to use the HTTPS endpoint
  # endpoints {
  #   s3 = "https://s3.ap-southeast-1.amazonaws.com"
  # }

  allowed_account_ids = ["864981712604"]  

  # This one enables a role to do terraform
  # assume_role {
  #   role_arn     = "arn:aws:iam::123456789012:role/MyRole"
  #   session_name = "TerraformSession"
  # }

  # Force all S3 requests to use HTTPS
  # s3_use_path_style           = false    # path style is the older, legacy system
  skip_credentials_validation = false    # Terraform validates AWS credentials during initialization
  # skip_metadata_api_check     = false    # checks EC2 instance metadata service (IMDS) for IAM credentials
  # s3_us_east_1_regional_endpoint = "regional"

  default_tags {
    tags = {
      Environment = "Sandbox"
      Department  = "DevOps"
      Terraform   = "True"
      Version     = "1"
      ExtraTags   = "LOLOL"
    }
  }

  # this one ignores the tags which are managed by other services
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
    keys = ["ManagedBy"]
  }
}

# Add to your existing providers
provider "tls" {}

provider "http" {
  # Configuration options
}