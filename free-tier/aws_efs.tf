resource "aws_efs_file_system" "sandbox_efs" {
  creation_token   = "sandbox-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = {
    Name = "sandbox-efs"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-security-group"
  description = "Security group for EFS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  # Note that EFS is only accessible internally from the VPC 
  # and not from public internet, so no use putting this here

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-security-group"
  }
}

# resource "aws_efs_mount_target" "efs_mount_target" {
#   file_system_id  = aws_efs_file_system.sandbox_efs.id
#   subnet_id       = module.vpc.public_subnets[0]
#   security_groups = [aws_security_group.efs_sg.id]
# }

## Mount Targets for Subnet A and B
resource "aws_efs_mount_target" "efs_mount_target_a" {
  file_system_id  = aws_efs_file_system.sandbox_efs.id
  subnet_id       = module.vpc.public_subnets[0] # Public Subnet A
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "efs_mount_target_b" {
  file_system_id  = aws_efs_file_system.sandbox_efs.id
  subnet_id       = module.vpc.public_subnets[1] # Public Subnet B
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "basic_access" {
  file_system_id = aws_efs_file_system.sandbox_efs.id
  posix_user {
    gid = 1001
    uid = 1001
  }
  root_directory {
    path = "/basic-access-point"
    creation_info {
      owner_gid   = 1001
      owner_uid   = 1001
      permissions = "755"
    }
  }
  tags = {
    Name = "basic-access-point"
  }
}

output "aws_efs_dns" {
  value = aws_efs_file_system.sandbox_efs.dns_name
}

output "aws_efs_mount_command" {
  value = "sudo mount -t efs -o tls,accesspoint=${aws_efs_access_point.basic_access.id} ${aws_efs_file_system.sandbox_efs.id}:/ /mnt/efs"
}

# Old: sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.sandbox_efs.dns_name}: /mnt/aws_efs

output "aws_efs_access_point" {
  value = aws_efs_access_point.basic_access.id
}

# module "efs" {
#   # https://registry.terraform.io/modules/terraform-aws-modules/efs/aws/latest
#   source  = "terraform-aws-modules/efs/aws"
#   version = "1.6.5"z`

#   # File system
#   name           = "sandbox-efs"
#   creation_token = null # unique thing for generation?
#   encrypted      = true # Uses the AWS KMS service key (aws/elasticfilesystem) by default
#   #   kms_key_arn    = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"

#   # performance_mode                = "generalPurpose" (default) or "maxIO" (expensive)
#   # NB! PROVISIONED TROUGHPUT MODE WITH 256 MIBPS IS EXPENSIVE ~$1500/month
#   # throughput_mode                 = "bursting" (default) or "provisioned" (expensive)
#   # provisioned_throughput_in_mibps = 256

#   # Comment out the lifecycle_policy to avoid transitioning to IA, which isn't part of the Free Tier
#   #   lifecycle_policy = {
#   #     transition_to_ia = "AFTER_30_DAYS"
#   #   }

#   # File system policy (simplified for free tier)
#   attach_policy = false # Remove policy unless specifically needed

#   #   bypass_policy_lockout_safety_check = false
#   #   policy_statements = [
#   #     {
#   #       sid     = "Example"
#   #       actions = ["elasticfilesystem:ClientMount"]
#   #       principals = [
#   #         {
#   #           type        = "AWS"
#   #           identifiers = ["arn:aws:iam::111122223333:role/EfsReadOnly"]
#   #         }
#   #       ]
#   #     }
#   #   ]

#   # Mount targets / security group (use ONE AZ to minimize costs)
#   mount_targets = {
#     "ap-southeast-1a" = {
#       subnet_id = module.vpc.public_subnets[0] # or alternatively, aws_instance.ubuntu[0].subnet_id
#     }
#   }

#   security_group_description = "Free Tier EFS security group"
#   security_group_vpc_id      = module.vpc.vpc_id
#   #   security_group_name        = "aws_efs_security_group"
#   security_group_rules = {
#     vpc = {
#       # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
#       description = "NFS ingress from VPC"
#       cidr_blocks = [module.vpc.vpc_cidr_block]
#     },
#     my_ip = {
#       description = "NFS ingress from my public IP"
#       cidr_blocks = [local.my_public_ip]
#     }
#   }


#   # Access points (free to use)
#   access_points = {
#     basic_access = {
#       name = "basic-access-point"
#     }
#   }

#   # Not sure how this is used
#   #   # Access point(s)
#   #   access_points = {
#   #     posix_example = {
#   #       name = "posix-example"
#   #       posix_user = {
#   #         gid            = 1001
#   #         uid            = 1001
#   #         secondary_gids = [1002]
#   #       }

#   #       tags = {
#   #         Additionl = "yes"
#   #       }
#   #     }
#   #     root_example = {
#   #       root_directory = {
#   #         path = "/example"
#   #         creation_info = {
#   #           owner_gid   = 1001
#   #           owner_uid   = 1001
#   #           permissions = "755"
#   #         }
#   #       }
#   #     }
#   #   }

#   # Disable backup policy to avoid potential charges
#   enable_backup_policy = false

#   # Replication configuration
#   create_replication_configuration = false
# }


# # Output the EFS DNS URL
# output "aws_efs_dns" {
#   value = module.efs.dns_name
# }

# output "mount_efs_command" {
#   value = "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${module.efs.dns_name}: /mnt/aws_efs"
# }
