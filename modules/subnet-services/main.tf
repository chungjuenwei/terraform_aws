
# Create the VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "vpc-main"
  }
}

# Local variables for CIDR calculations
locals {
  vpc_mask = parseint(split("/", var.vpc_cidr)[1], 10)
  service_27_cidrs = [
    for i in range(length(var.service_names)) : cidrsubnet(var.vpc_cidr, 27 - local.vpc_mask, i)
  ]
  default_nacl_rules = [
    {
      protocol   = "-1"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
      direction  = "ingress"
    },
    {
      protocol   = "-1"
      rule_no    = 100
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = 0
      to_port    = 0
      direction  = "egress"
    }
  ]
}

# Create first /28 subnet (in az1) for each service
resource "aws_subnet" "service_a" {
  count             = length(var.service_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.service_27_cidrs[count.index], 1, 0) # First /28
  availability_zone = var.az1
  tags = {
    Name = "subnet-${var.service_names[count.index]}-a"
  }
}

# Create second /28 subnet (in az2) for each service
resource "aws_subnet" "service_b" {
  count             = var.env_name == "dev" || var.env_name == "uat" ? 0 : length(var.service_names)
  # count             = length(var.service_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.service_27_cidrs[count.index], 1, 1) # Second /28
  availability_zone = var.az2
  tags = {
    Name = "subnet-${var.service_names[count.index]}-b"
  }
}

# Create a route table for each service
resource "aws_route_table" "service_rt" {
  count  = length(var.service_names)
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "rt-${var.service_names[count.index]}"
  }
}

# Associate subnet_a with the route table
resource "aws_route_table_association" "service_a_assoc" {
  count          = length(var.service_names)
  subnet_id      = aws_subnet.service_a[count.index].id
  route_table_id = aws_route_table.service_rt[count.index].id
}

# Associate subnet_b with the route table (only if subnet_b exists)
resource "aws_route_table_association" "service_b_assoc" {
  count          = var.env_name == "dev" || var.env_name == "uat" ? 0 : length(var.service_names)
  subnet_id      = aws_subnet.service_b[count.index].id
  route_table_id = aws_route_table.service_rt[count.index].id
}

# Create a network ACL for each service with dynamic rules
resource "aws_network_acl" "service_nacl" {
  count  = length(var.service_names)
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = [for rule in lookup(var.service_nacl_rules, var.service_names[count.index], local.default_nacl_rules) : rule if rule.direction == "ingress"]
    content {
      protocol   = ingress.value.protocol
      rule_no    = ingress.value.rule_no
      action     = ingress.value.action
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = [for rule in lookup(var.service_nacl_rules, var.service_names[count.index], local.default_nacl_rules) : rule if rule.direction == "egress"]
    content {
      protocol   = egress.value.protocol
      rule_no    = egress.value.rule_no
      action     = egress.value.action
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = {
    Name = "nacl-${var.service_names[count.index]}"
  }
}

# Associate subnet_a with the NACL
resource "aws_network_acl_association" "service_a_assoc" {
  count          = length(var.service_names)
  subnet_id      = aws_subnet.service_a[count.index].id
  network_acl_id = aws_network_acl.service_nacl[count.index].id
}

# Associate subnet_b with the NACL
resource "aws_network_acl_association" "service_b_assoc" {
  count          = var.env_name == "dev" || var.env_name == "uat" ? 0 : length(var.service_names)
  subnet_id      = aws_subnet.service_b[count.index].id
  network_acl_id = aws_network_acl.service_nacl[count.index].id
}

# Creates sg for service (optional)
resource "aws_security_group" "service_sg" {
  count  = length(var.service_names)
  name   = "sgrp-${var.service_names[count.index]}"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = lookup(var.service_sg_ingress_rules, var.service_names[count.index], [])
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = lookup(var.service_sg_egress_rules, var.service_names[count.index], [{
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }])
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  # Allow all outbound traffic by default (optional)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Outputs
output "number_of_27_cidrs" {
  value       = pow(2, 27 - local.vpc_mask)
  description = "Number of /27 CIDR blocks that fit within the VPC CIDR"
}

output "service_cidr_mapping" {
  value = {
    for i in range(length(var.service_names)) : var.service_names[i] => {
      "27_cidr"   = local.service_27_cidrs[i]
      "28_cidr_a" = aws_subnet.service_a[i].cidr_block
      "28_cidr_b" = try(aws_subnet.service_b[i].cidr_block, null)
    }
  }
  description = "Map of service names to their /27 and /28 CIDR blocks"
}

output "service_subnet_ids" {
  value = {
    for i in range(length(var.service_names)) : var.service_names[i] => {
      "subnet_a_id" = aws_subnet.service_a[i].id
      "subnet_b_id" = try(aws_subnet.service_b[i].id, null)
    }
  }
}
