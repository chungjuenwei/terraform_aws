# Define input variables
variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC (e.g., 10.20.28.0/25)"
}

variable "env_name" {
  type        = string
  description = "Environment name (e.g., 'dev', 'uat', 'prd')"
}

variable "service_names" {
  type        = list(string)
  description = "List of service names (e.g., ['service1', 'service2'])"
}

variable "az1" {
  type        = string
  description = "First Availability Zone (e.g., us-east-1a)"
  default = "ap-southeast-1a"
}

variable "az2" {
  type        = string
  description = "Second Availability Zone (e.g., us-east-1b)"
  default = "ap-southeast-1b"
}

variable "service_nacl_rules" {
  type = map(list(object({
    protocol   = string
    rule_no    = number
    action     = string
    cidr_block = string
    from_port  = number
    to_port    = number
    direction  = string # "ingress" or "egress"
  })))
  description = "Map of service names to their NACL rules"
  default     = {}
}

variable "service_sg_ingress_rules" {
  type = map(list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  })))
  default = {}
}

variable "service_sg_egress_rules" {
  type = map(list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  })))
  default = {}
}