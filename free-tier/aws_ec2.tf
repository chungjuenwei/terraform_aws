# Change this to stop creating EC2
variable "create_ec2" {
  description = "Flag to create EC2 instance"
  type        = bool
  default     = true # Set to false to disable EC2 creation
}


## Creates 3 keys: ubuntu, foldersyncuser and user1

# Generate SSH keys for each user
resource "tls_private_key" "ubuntu" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "foldersyncuser" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "user1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private keys to local files
resource "local_file" "ubuntu_private_key" {
  content  = tls_private_key.ubuntu.private_key_openssh
  filename = "${path.module}/.ssh/ubuntu.pem"
  file_permission = "0400"
}

resource "local_file" "foldersyncuser_private_key" {
  content  = tls_private_key.foldersyncuser.private_key_openssh
  filename = "${path.module}/.ssh/foldersyncuser.pem"
  file_permission = "0400"
}

resource "local_file" "user1_private_key" {
  content  = tls_private_key.user1.private_key_openssh
  filename = "${path.module}/.ssh/user1.pem"
  file_permission = "0400"
}

# Save the public keys to local files
resource "local_file" "ubuntu_public_key" {
  content  = tls_private_key.ubuntu.public_key_openssh
  filename = "${path.module}/.ssh/ubuntu.pub"
}

resource "local_file" "foldersyncuser_public_key" {
  content  = tls_private_key.foldersyncuser.public_key_openssh
  filename = "${path.module}/.ssh/foldersyncuser.pub"
}

resource "local_file" "user1_public_key" {
  content         = tls_private_key.user1.public_key_openssh
  filename        = "${path.module}/.ssh/user1.pub"
  file_permission = "0400"
}

## This part gets my public ip and automates it such that ssh is only accessible by my IP


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

  ## Not necessary for now, since opening all ports for my ip address
  # ingress {
  #   description = "SSH access from my public IP"
  #   from_port   = random_integer.ssh_port.result
  #   to_port     = random_integer.ssh_port.result
  #   protocol    = "tcp"
  #   cidr_blocks = [local.my_public_ip]
  # }

  # Since I will be accepting incoming traffic for ephemeral ports, like 8000 or 9000
  ingress {
    description = "Allows all ports from my IP"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  # ingress {
  #   description = "STUN helps devices discover their public IP and port for direct connections"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = [local.my_public_ip]
  # }

  # ingress {
  #   description = "STUN helps devices discover their public IP and port for direct connections"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = [local.my_public_ip]
  # }

  # ingress {
  #   description = "Tailscale WireGuard peer-to-peer relay"
  #   from_port   = 41641
  #   to_port     = 41641
  #   protocol    = "udp"
  #   cidr_blocks = [local.my_public_ip]
  # }

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
    users:
      - name: ubuntu
        groups: sudo
        shell: /bin/bash
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${tls_private_key.ubuntu.public_key_openssh}

      - name: foldersyncuser
        shell: /usr/sbin/nologin
        ssh_authorized_keys:
          - ${tls_private_key.foldersyncuser.public_key_openssh}

      - name: user1
        shell: /bin/bash
        ssh_authorized_keys:
          - ${tls_private_key.user1.public_key_openssh}

    package_update: true
    package_upgrade: true
    packages:
      - fail2ban
      - snapd
      - python3-pip
      - nfs-common
      - unzip  # Required for AWS CLI installation
      - awscli
      - git
      - binutils
      - rustc
      - cargo
      - pkg-config
      - libssl-dev
      - gettext

    write_files:
    - path: /etc/ssh/sshd_config.d/99-custom-ssh-port.conf
      content: |
        Port ${random_integer.ssh_port.result}
        PermitRootLogin no
        PasswordAuthentication no

    - path: /etc/ssh/sshd_config.d/foldersyncuser.conf
      content: |
        Match User foldersyncuser
            ChrootDirectory /home/foldersyncuser
            ForceCommand internal-sftp
            AllowTcpForwarding no
            X11Forwarding no

    runcmd:
      # This creates the foldersyncuser directory
      - bash -c 'mkdir -p /home/foldersyncuser/{pictures,documents,music,videos}'
      - chown -R foldersyncuser:foldersyncuser /home/foldersyncuser
      - chmod 755 /home/foldersyncuser

      # Configures SSH for Custom Random Port
      - systemctl restart sshd
      - ufw allow ${random_integer.ssh_port.result}/tcp
      - ufw --force enable

      # Install & Start SSM Agent (for Ubuntu)
      - snap install amazon-ssm-agent --classic
      - systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent
      - systemctl start snap.amazon-ssm-agent.amazon-ssm-agent

      # Install AWS CLI
      - curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
      - unzip /tmp/awscliv2.zip -d /tmp
      - /tmp/aws/install

      # Install efs-utils
      # - git clone https://github.com/aws/efs-utils /tmp/efs-utils
      # - cd /tmp/efs-utils && ./build-deb.sh
      # - apt-get install -y /tmp/efs-utils/build/amazon-efs-utils*.deb

      # Clean up temporary files
      # - rm -rf /tmp/awscliv2.zip /tmp/aws /tmp/efs-utils

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

# # Allocate an Elastic IP
# resource "aws_eip" "ec2_eip" {
#   count    = var.create_ec2 ? 1 : 0
#   domain   = "vpc"
#   instance = aws_instance.ubuntu[0].id # Associate directly
# }


# Version trigger for EC2 recreation
resource "null_resource" "ec2_recreate_trigger" {
  triggers = {
    version = 1 # Update this variable to trigger recreation
  }
}

# EC2 Instance
resource "aws_instance" "ubuntu" {
  count = var.create_ec2 ? 1 : 0

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # Free tier eligible
  # key_name      = aws_key_pair.ec2_key.key_name # not necessary because 
  # key pair is specified in cloudinit

  associate_public_ip_address = true

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name # Attach SSM role

  user_data = data.cloudinit_config.ec2_config.rendered

  tags = {
    Name = "ubuntu-free-tier"
  }

  # Free tier storage configuration
  root_block_device {
    volume_size = 30 # GB (Free tier allows up to 30 GB)
    volume_type = "gp2"
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.ec2_recreate_trigger.id
    ]
  }

  depends_on = [null_resource.ec2_recreate_trigger]
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
output "aws_ec2_ssh_command" {
  value = "ssh -i ${local_file.ubuntu_private_key.filename} ubuntu@${aws_instance.ubuntu[0].public_ip} -p ${random_integer.ssh_port.result}"
}

# Output connection information
output "aws_ec2_ssh_tnc_command" {
  value = "tnc ${aws_instance.ubuntu[0].public_ip} -p ${random_integer.ssh_port.result}"
}
