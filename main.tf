#to start terraform provider code
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}
#keypair second method for Key_pair

resource "aws_key_pair" "TF_key" {
  key_name   = "TF_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "TF-key" {
    content  = tls_private_key.rsa.private_key_pem
    filename = "TF-key"
}
#To create vpc
variable "vpc-parameter"{
    description = "CIDR range for the VPC"
    #default = "10.1.0.0/16"
}
# 1. Create a VPC
resource "aws_vpc" "testVpc" {
  cidr_block = var.vpc-parameter
  tags = {
      Name = "testVpc"
  }
}
# 2.Attach an Internet gateway to the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.testVpc.id
availability_zone = us-east-1c

  tags = {
    Name = "myIGW"
  }
}
# 3. Create a subnet
resource "aws_subnet" "my-subnet-1" {
  vpc_id     = aws_vpc.testVpc.id
  cidr_block = "10.1.0.0/24"

  tags = {
    Name = "Subnet-1"
  }
}
# 4. Create a Route table
resource "aws_route_table" "example" {
  vpc_id = aws_vpc.testVpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
    }

   route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
    }

  tags = {
    Name = "DemoRT"
  }
}
# 5. Associate subnet with Route Table
resource "aws_route_table_association" "exampleAssociation" {
  subnet_id      = aws_subnet.my-subnet-1.id
  route_table_id = aws_route_table.example.id
}
# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "terraform-sg" {
  name        = "terraform-sg"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.testVpc.id

  ingress{
      description      = "HTTPS TRAFFIC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
  ingress {
      description      = "HTTP TRAFFIC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress {
      description      = "ssh TRAFFIC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  egress{
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  tags = {
    Name = "allow_web-traffic"
  }
}

resource "aws_iam_role" "example_role" {
  name = "examplerole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "example_attachment" {
  role       = aws_iam_role.example_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "example_profile" {
  name = "example_profile"
  role = aws_iam_role.example_role.name
}

resource "aws_instance" "web" {
  ami           = "ami-05c13eab67c5d8861" #Amazon Linux AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.TF_key.key_name
  vpc_security_group_ids = [aws_security_group.terraform-sg.id]
  subnet_id = aws_subnet.my-subnet-1.id
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.example_profile.name
  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "HelloWorld1"
  }
}

