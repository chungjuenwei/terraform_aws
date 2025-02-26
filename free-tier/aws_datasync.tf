# ## THIS IS ONLY AN EXAMPLE, have yet to get the actual use case

# Uncomment to try

# # EC2 Instance to simulate on-premises NFS server

# # 1. aws_datasync_agent (On-Premises Agent)

# resource "aws_instance" "nfs_server" {
#   ami           = "ami-0e4b5d31e60c96243"  # Amazon Linux 2 in ap-southeast-1, update as needed
#   instance_type = "t2.micro"               # Free-tier eligible
#   subnet_id     = module.vpc.private_subnets[0]
#   vpc_security_group_ids = [aws_security_group.nfs_sg.id]
#   key_name      = "my-key-pair"            # Replace with your key pair

#   user_data = <<EOF
# #!/bin/bash
# yum update -y
# yum install -y nfs-utils
# mkdir -p /nfs/share
# echo "/nfs/share *(rw,sync,no_subtree_check)" >> /etc/exports
# systemctl enable nfs-server
# systemctl start nfs-server
# echo "timestamp,page,user_id,ip_address" > /nfs/share/traffic_logs.csv
# echo "2025-02-24 08:15:00,/home,user123,192.168.1.1" >> /nfs/share/traffic_logs.csv
# chmod -R 777 /nfs/share
# EOF

#   tags = { Name = "nfs-server" }
# }

# # Security Group for EC2/NFS
# resource "aws_security_group" "nfs_sg" {
#   name        = "nfs-sg"
#   vpc_id      = module.vpc.vpc_id
#   ingress {
#     from_port   = 2049  # NFS
#     to_port     = 2049
#     protocol    = "tcp"
#     cidr_blocks = [module.vpc.vpc_cidr_block]
#   }
#   ingress {
#     from_port   = 22    # SSH for setup
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [local.my_public_ip]
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # DataSync Agent
# resource "aws_datasync_agent" "nfs_agent" {
#   ip_address   = aws_instance.nfs_server.private_ip
#   name         = "nfs-datasync-agent"
#   # Note: In real on-premises scenarios, you'd deploy the agent binary manually or via SSM
#   # Here, we assume the agent is activated on the EC2 instance
# }

# # 2. aws_datasync_task (Defines Source/Destination, e.g., NFS to S3)

# # DataSync Location: NFS Source
# resource "aws_datasync_location_nfs" "source" {
#   server_hostname = aws_instance.nfs_server.private_ip
#   subdirectory    = "/nfs/share"
#   on_prem_config {
#     agent_arns = [aws_datasync_agent.nfs_agent.arn]
#   }
# }

# # DataSync Location: S3 Destination
# resource "aws_datasync_location_s3" "destination" {
#   s3_bucket_arn = aws_s3_bucket.traffic_logs.arn
#   subdirectory  = "/logs"
#   s3_config {
#     bucket_access_role_arn = aws_iam_role.datasync_s3_role.arn
#   }
# }

# # IAM Role for DataSync to Access S3
# resource "aws_iam_role" "datasync_s3_role" {
#   name = "datasync-s3-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Effect    = "Allow"
#         Principal = { Service = "datasync.amazonaws.com" }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "datasync_s3_policy" {
#   role = aws_iam_role.datasync_s3_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = ["s3:PutObject", "s3:GetBucketLocation", "s3:ListBucket"]
#         Resource = [aws_s3_bucket.traffic_logs.arn, "${aws_s3_bucket.traffic_logs.arn}/*"]
#       }
#     ]
#   })
# }

# # DataSync Task
# resource "aws_datasync_task" "nfs_to_s3" {
#   source_location_arn      = aws_datasync_location_nfs.source.arn
#   destination_location_arn = aws_datasync_location_s3.destination.arn
#   name                     = "nfs-to-s3-task"
#   options {
#     verify_mode = "ONLY_FILES_TRANSFERRED"  # Verify data integrity
#     transfer_mode = "CHANGED"              # Only sync changed files
#   }
# }

# # 3. Schedule with aws_datasync_task_schedule

# resource "aws_cloudwatch_event_rule" "datasync_schedule" {
#   name                = "datasync-daily-sync"
#   description         = "Triggers DataSync task daily"
#   schedule_expression = "cron(0 0 * * ? *)"  # Daily at midnight UTC
# }

# resource "aws_cloudwatch_event_target" "datasync_target" {
#   rule      = aws_cloudwatch_event_rule.datasync_schedule.name
#   target_id = "runDatasyncTask"
#   arn       = aws_datasync_task.nfs_to_s3.arn
#   role_arn  = aws_iam_role.datasync_event_role.arn
# }

# resource "aws_iam_role" "datasync_event_role" {
#   name = "datasync-event-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Effect    = "Allow"
#         Principal = { Service = "events.amazonaws.com" }
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy" "datasync_event_policy" {
#   role = aws_iam_role.datasync_event_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect   = "Allow"
#         Action   = "datasync:StartTaskExecution"
#         Resource = aws_datasync_task.nfs_to_s3.arn
#       }
#     ]
#   })
# }