variable "ssh_key_path" {}
variable "project_name" {}
variable "region_name" {}
variable "vpc_id"{}
variable "instance_type" {}

provider "aws" {
  region     = var.region_name
}

resource "aws_key_pair" "deployer-key" {
  key_name      = "${var.project_name}-deployer-key"
  public_key    = file(var.ssh_key_path)
}


resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_http" {
    name        = "allow_http"
    description = "Allow http inbound traffic"
    vpc_id      = var.vpc_id

    ingress {
      description = "http from VPC"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "allow_http"
    }
  }

data "template_file" "userdata" {
  template = file("${path.module}/userdata.sh")
}


resource "aws_instance" "app_server" {
  ami               = "ami-0b8b44ec9a8f90422"
  instance_type     = var.instance_type
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.allow_http.id
  ]
  user_data = data.template_file.userdata.rendered
  key_name  = aws_key_pair.deployer-key.key_name
  tags = {
    Name = "${var.project_name}-web-instance"
  }
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}

output "private_ip" {
  value = aws_instance.app_server.private_ip
}

output "ssh" {
  value = "ssh -l ubuntu ${aws_eip.eip.public_ip}"
}
output "url" {
  value = "http://${aws_eip.eip.public_ip}/"
}
