# Create VPC with public/private subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"

  name = "free-tier-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = false  # NAT Gateway is not free tier eligible
  enable_vpn_gateway = false

  # Enable creation of a database subnet group
  create_database_subnet_group = true

  # Tags have been added at the provider level
  # tags = {
  #   Terraform   = "true"
  #   Environment = "Sandbox"
  # }
}