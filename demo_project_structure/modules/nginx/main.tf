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

data "aws_eip" "nginx" {
  public_ip = var.eip == "new" ? aws_eip.nginx[0].public_ip : var.eip
}

resource "aws_eip" "nginx" {
  count = var.eip == "new" ? 1 : 0
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.nginx.id
  allocation_id = data.aws_eip.nginx.id
}

resource "aws_instance" "nginx" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = var.security_groups
  subnet_id = var.subnet_id

  root_block_device {
    volume_type = "gp2"
    volume_size = 30
  }

  user_data = file("../commons/install_nginx.sh")

  tags = {"Name":"TERRAFORM-NGINX-INSTANCE"}
}

output "nginx_url" {
  description = "nginx url"
  value       = "http://${data.aws_eip.nginx.public_dns}"
}