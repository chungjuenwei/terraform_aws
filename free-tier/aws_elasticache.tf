# Create a security group for the ElastiCache cluster
resource "aws_security_group" "redis_sg" {
  name        = "redis-security-group"
  description = "Security group for Redis ElastiCache"
  vpc_id      = module.vpc.vpc_id # This specifies which VPC this security group is created in

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Restrict this to IP VPC CIDR
  }

  # Not necessary because elasticache is only in private subnet now
  # ingress {
  #   from_port   = 6379
  #   to_port     = 6379
  #   protocol    = "tcp"
  #   cidr_blocks = [local.my_public_ip] # Restrict this to my public IP
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "redis-security-group"
  }
}

# Create an ElastiCache Redis cluster
resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "redis-demo-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro" # Change to a different instance type if needed
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  port                 = 6379
  security_group_ids   = [aws_security_group.redis_sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
}

# Create a subnet group for the ElastiCache cluster
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = module.vpc.private_subnets # Replace with your subnet IDs
}

# Output the Redis endpoint
output "aws_elasticache_redis_endpoint" {
  value = aws_elasticache_cluster.redis_cluster.cache_nodes[0].address
}
