provider "aws" { region = "us-west-2" }

provider "cloudflare" {}

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# IAM Role for EC2 (ECR pull)
resource "aws_iam_role" "ec2_role" {
  name = "kamal-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # Pull only
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "kamal-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ECR Repo
resource "aws_ecr_repository" "money_app" {
  name = "money-app"
}

# Get latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical's AWS account ID
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Cloudflare IP ranges
data "http" "cloudflare_ips" {
  url = "https://www.cloudflare.com/ips-v4"
}

locals {
  cloudflare_cidr_blocks = split("\n", trimspace(data.http.cloudflare_ips.response_body))
}

# Security Group
resource "aws_security_group" "sg" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Consider restricting to your IP
  }
  ingress {
    description = "HTTP from Cloudflare"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.cloudflare_cidr_blocks
  }
  ingress {
    description = "HTTPS from Cloudflare"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.cloudflare_cidr_blocks
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance (installs Docker)
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name  # Your SSH key
  vpc_security_group_ids = [aws_security_group.sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    systemctl enable docker
    
    # Format and mount EBS volume
    mkfs -t ext4 /dev/sdf
    mkdir -p /data
    mount /dev/sdf /data
    echo '/dev/sdf /data ext4 defaults,nofail 0 2' >> /etc/fstab
    
    # Create app data directory
    mkdir -p /data/money
    chown -R ec2-user:ec2-user /data
  EOF

  tags = { Name = "Money-App" }
}

# EBS Volume for data persistence
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.app_server.availability_zone
  size              = 20
  type              = "gp3"
  tags = { Name = "money-app-data" }
}

resource "aws_volume_attachment" "data_attachment" {
  device_name = "/dev/sdf"
  instance_id = aws_instance.app_server.id
  volume_id   = aws_ebs_volume.data.id
}

# IAM User for Kamal deploy (push/pull ECR)
resource "aws_iam_user" "deploy_user" { name = "kamal-deploy" }

resource "aws_iam_access_key" "deploy_key" {
  user = aws_iam_user.deploy_user.name
}

resource "aws_iam_user_policy" "ecr_policy" {
  user   = aws_iam_user.deploy_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
      Resource = "*"
    }]
  })
}

variable "key_name" { 
  type        = string
  description = "SSH key name for EC2 instance access"
  default     = "chris"
}

variable "cloudflare_zone_id" { 
  type        = string
  description = "Cloudflare zone ID for your domain"
  default     = "c0da0acfd434bbf09c52393f1927c6b1"
}

# Cloudflare DNS Record
resource "cloudflare_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = "money"
  content = aws_instance.app_server.public_ip
  type    = "A"
  proxied = true
}

output "ecr_url" { value = aws_ecr_repository.money_app.repository_url }
output "deploy_access_key" { value = aws_iam_access_key.deploy_key.id }
output "deploy_secret_key" { 
  value     = aws_iam_access_key.deploy_key.secret
  sensitive = true
}
output "ec2_ip" { value = aws_instance.app_server.public_ip }
output "domain_name" { value = cloudflare_record.app.hostname }
