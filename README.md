# Creación de un servidor Nginx con PHP
## Paso 1. Instalar AWS CLI
Se puede instalar el CLI para configurar nuestra cuenta de AWS desde el siguiente [link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
## Paso 2. Crear claves de acceso en AWS
En este caso crearemos un usuario de IAM para obtener las claves de acceso de este (práctica recomendada por el mismo AWS) asignándole la política _AmazonEC2FullAccess_
![Creación de usuario IAM](/images/creacion_user_iam.png)
## Paso 3. Configurar las claves de acceso desde AWS CLI
![aws configure](/images/aws_configure.png)
## Paso 4. Crear claves SSH
![Crear lave SSH](/images/ssh_keys.png)
![Crear lave SSH](/images/ssh_keys2.png)
## Paso 5. Crear el archivo terrafrom.tfvars
En este archivo vamos a añadir las variables para nuestro proyecto
terraform.tfvars
```
ssh_key_path="/home/jesu/.ssh/id_rsa.pub"
project_name="ngnix_example"
region_name="us-east-1"
availability_zone="us-east-1"
vpc_id="vpc-XXXXX"
instance_type="t2.micro"
```
## Paso 6. Crear el archivo versions.tf
versions.tf
```
terraform {
	required_providers {
		aws =  {
			source  =  "hashicorp/aws"
			version  =  "~> 4.16"
		}
	}
	required_version =  ">= 1.2.0"
}
```
## Paso 7. Crear el archivo main.tf
main.tf
```
variable "ssh_key_path" {}
variable "project_name" {}
variable "region_name" {}
variable "availability_zone" {}
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
  availability_zone = var.availability_zone
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
```
## Paso 8. Crear script de ansible
Vamos a crear un listado de comandos que se ejecutarán en la máquina instanciada para poder instalar ansible y posteriormente PHP junto con Ngnix
