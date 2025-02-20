output "aws_vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}


## Gets AWS Account ID

data "aws_caller_identity" "current" {}

output "_aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

## Gets current AWS Region

data "aws_region" "current" {}

output "_current_aws_region" {
  value = data.aws_region.current.name
}

## Prints Hello from Terraform

# resource "null_resource" "example" {
#   provisioner "local-exec" {
#     command = "echo 'Hello from Terraform!'"
#   }
# }


## This uses the windows powershell command
# resource "terraform_data" "example2" {
#   provisioner "local-exec" {
#     command     = "Get-Date > completed.txt"
#     interpreter = ["PowerShell", "-Command"]
#   }
# }
