# Change this to stop creating EC2
variable "create_ec2" {
  description = "Flag to create EC2 instance"
  type        = bool
  default     = true  # Set to false to disable EC2 creation
}

# Create SSH key pair
resource "tls_private_key" "ec2_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-ssh-key"
  public_key = tls_private_key.ec2_ssh.public_key_openssh
}

## This part gets my public ip and automates it such that ssh is only accessible by my IP

# Fetch current public IP dynamically
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/" # Fetches your public IP
}

# Trim the newline character from the response
locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

# Generate random SSH port between 40000-49999
resource "random_integer" "ssh_port" {
  min = 40000
  max = 49999
}

# Security group for EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow SSH access on random port"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access from my public IP"
    from_port   = random_integer.ssh_port.result
    to_port     = random_integer.ssh_port.result
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    description = "STUN helps devices discover their public IP and port for direct connections"
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    description = "Headscale control server (main API)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    description = "gRPC API (optional, for automation)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  ingress {
    description = "Tailscale WireGuard peer-to-peer relay"
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = [local.my_public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

# Cloud-init configuration
data "cloudinit_config" "ec2_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - fail2ban
      - snapd
      - python3-pip

    write_files:
    - path: /etc/ssh/sshd_config.d/99-custom-ssh-port.conf
      content: |
        Port ${random_integer.ssh_port.result}
        PermitRootLogin no
        PasswordAuthentication no

    runcmd:
      - systemctl restart sshd
      - ufw allow ${random_integer.ssh_port.result}/tcp
      - ufw --force enable

      # Install & Start SSM Agent (for Ubuntu)
      - snap install amazon-ssm-agent --classic
      - systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
      - systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

      # Install Docker using convenience script
      - curl -fsSL https://get.docker.com | bash
      - usermod -aG docker ubuntu
      - newgrp docker  # Apply group change immediately

    power_state:
      mode: reboot
      message: "Rebooting after initial setup"
      timeout: 30

    EOT
  }
}

# Allocate an Elastic IP
resource "aws_eip" "ec2_eip" {
  count  = var.create_ec2 ? 1 : 0
  domain = "vpc"
  instance = aws_instance.ubuntu[0].id  # Associate directly
}

# EC2 Instance
resource "aws_instance" "ubuntu" {
  count         = var.create_ec2 ? 1 : 0
  
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"  # Free tier eligible
  key_name      = aws_key_pair.ec2_key.key_name

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name  # Attach SSM role

  user_data = data.cloudinit_config.ec2_config.rendered

  tags = {
    Name = "ubuntu-free-tier"
  }

  # Free tier storage configuration
  root_block_device {
    volume_size = 30  # GB (Free tier allows up to 30 GB)
    volume_type = "gp2"
  }
}

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}


## Creates SSM role for EC2 and attaches it to EC2
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Output connection information
output "ssh_command" {
  value = "ssh -i ec2-key.pem ubuntu@${aws_eip.ec2_eip[0].public_ip} -p ${random_integer.ssh_port.result}"
}

# Save private key to file
resource "local_file" "ssh_private_key" {
  content  = tls_private_key.ec2_ssh.private_key_pem
  filename = "ec2-key.pem"
  file_permission = "0400"
}