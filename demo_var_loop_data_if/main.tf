provider "aws" {
  region = "eu-west-1"
}

variable "subnet_index" {
  type = number
  description = "subnet index in 10.{}.0.0"
}

variable "nginx_instance_type" {}
variable "nginx_eip" {}

locals {
  ports = [22, 80]
}

data "aws_ami" "amazon_linux" {
most_recent = true
owners = ["amazon"]
  filter {
      name   = "name"
      values = ["amzn-ami-hvm-2018.03.0.20190826-x86_64-gp2"]
  }
  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.${var.subnet_index}.0.0/24"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"

  tags = {"Name":"TERRAFORM-VPC"}
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {"Name":"TERRAFORM-IGW"}
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  cidr_block              = "10.${var.subnet_index}.0.0/28"
  availability_zone       = "eu-west-1a"

  tags = {"Name":"TERRAFORM-PUBLIC-SUBNET"}
}

resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "pub_igw" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.pub_rt.id
}


resource "aws_security_group" "nginx_sg" {
  name        = "TERRAFORM-NGINX-SG"
  description = "Nginx security group"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "nginx_sg_internet_https_rule" {
  count       = 2
  type        = "ingress"
  from_port   = element(local.ports, count.index)
  to_port     = element(local.ports, count.index)
  protocol    = "tcp"
  security_group_id = aws_security_group.nginx_sg.id
  cidr_blocks = ["0.0.0.0/0"]
}

// resource "aws_security_group_rule" "nginx_sg_vpn_ssh_rule" {
//   type        = "ingress"
//   from_port   = 22
//   to_port     = 22
//   protocol    = "tcp"
//   security_group_id = aws_security_group.nginx_sg.id
//   cidr_blocks = ["0.0.0.0/0"]
// }

data "aws_eip" "nginx" {
  public_ip = var.nginx_eip == "new" ? aws_eip.nginx[0].public_ip : var.nginx_eip
}

resource "aws_eip" "nginx" {
  count = var.nginx_eip == "new" ? 1 : 0
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.nginx.id
  allocation_id = data.aws_eip.nginx.id
}

resource "aws_instance" "nginx" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.nginx_instance_type
  key_name = "DEMO-KEY"
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]
  subnet_id = aws_subnet.public_subnet.id

  root_block_device {
    volume_type = "gp2"
    volume_size = 30
  }

  user_data = <<-EOF
            #!/bin/bash
            yum install nginx -y
            service nginx start
  EOF

  tags = {"Name":"TERRAFORM-NGINX-INSTANCE"}
}

output "nginx_url" {
  description = "nginx url"
  value       = "http://${data.aws_eip.nginx.public_dns}"
}