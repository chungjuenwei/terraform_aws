module "vpc_subnet_config" {
  source = "../../modules/subnet-services"
  env_name = "dev"
  # to add vpc name
  existing_vpc_id = aws_vpc.main.id # Replace with the actual ID of your existing VPC
  service_names = ["service1", ] # "s3-interface-endpoint",  "service3"
  service_nacl_rules = {
    "service1" = [
      # Allow incoming HTTPS (port 443) from 10.100.38.0/24
      {
        protocol   = "tcp"
        rule_no    = 100
        action     = "allow"
        cidr_block = "10.100.38.0/24"
        from_port  = 443
        to_port    = 443
        direction  = "ingress"
      },
      # Allow ephemeral ports (1024-65535) for return traffic to 10.100.38.0/24
      {
        protocol   = "tcp"
        rule_no    = 110
        action     = "allow"
        cidr_block = "10.100.38.0/24"
        from_port  = 1024
        to_port    = 65535
        direction  = "egress"
      }
    ]
  }
    service_sg_ingress_rules = {
      "service1" = [
        {
          from_port   = 443
          to_port     = 443
          protocol    = "tcp"
          cidr_blocks = ["10.100.38.0/24"]
          description = "Allow incoming 443 from here"
        }
      ]
    }
  service_sg_egress_rules = {
    "service1" = [
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.100.38.0/24"]
        description = "Allow outgoing 443 from here"
      }
    ]
  }
}

# Optionally, output the CIDR mapping
output "cidr_mapping" {
  value = module.vpc_subnet_config.service_cidr_mapping
}

output "service_subnet_ids" {
  value = module.vpc_subnet_config.service_subnet_ids
}
## How to use
# subnet_id = module.vpc_subnet_config.service_subnet_ids["service2"]["subnet_a_id"]



resource "aws_vpc" "main" {
  cidr_block = "10.188.91.0/25"
  tags = {
    Name = "poc-vpc"
  }
}