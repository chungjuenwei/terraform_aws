module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"
  # insert the 1 required variable here
  identifier = random_pet.rds_name.id  

  # PostgreSQL specific configuration
  engine               = "postgres"          # Changed from mysql
  engine_version       = "17.2"              # Latest PostgreSQL version as of 2023-10
  family               = "postgres17"        # Parameter group family
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  max_allocated_storage = 20
  # Performance and scaling
  storage_type           = "gp2"

  # Disable creation of RDS instance(s)
  create_db_instance = false

  db_name  = "mydatabase"
  username = "postgres"
  password = "securepassword123"
  port     = 42761                  # Custom PostgreSQL port

  # PostgreSQL specific parameters
  parameters = [
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "rds.force_ssl"
      value = "0"  # Set to 1 to enforce SSL in production
    }
  ]

  # Network configuration (updated security group)
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false

  # Backup & maintenance (adjusted for PostgreSQL)
  backup_retention_period = 0
  maintenance_window      = "Sun:00:00-Sun:03:00"
  backup_window           = "03:00-06:00"
  skip_final_snapshot     = true  # For dev environments only

  # PostgreSQL specific performance configuration
  # max_connections         = 100   # Default is autocalculated
  performance_insights_enabled = false  # Disable to save costs

  # Security
  monitoring_interval = 0    # disables Enhanced Monitoring for free tier

  # Disable features that incur costs
  multi_az               = false
  storage_encrypted      = false
  create_cloudwatch_log_group = false

  # Tags
  # tags = {
  #   # Tags have been added by the default tags
  #   Terraform   = "True"
  # }
}


# Updated Security Group for PostgreSQL
resource "aws_security_group" "rds_sg" {
  name        = "postgres-sg"
  description = "Allow PostgreSQL access from within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 42761  # Changed to Custom Port 42761 (PostgreSQL)
    to_port     = 42761
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-security-group"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "RDS subnet group"
  }
}