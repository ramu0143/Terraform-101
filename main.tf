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
# 7. Create a Network interface
resource "aws_network_interface" "testNic" {
  subnet_id       = aws_subnet.my-subnet-1.id
  private_ips     = ["10.1.0.50"]
  security_groups = [aws_security_group.terraform-sg.id]
}
# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.testNic.id
  associate_with_private_ip = "10.1.0.50"
  depends_on                = [aws_internet_gateway.gw]
}

# 9. Create Linux server 
resource "aws_instance" "web" {
  ami           = "ami-03a6eaae9938c858c" #Amazon Linux AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.TF_key.key_name
   // Attach the security group to the EC2 instance
  vpc_security_group_ids = [aws_security_group.terraform-sg.id]
  subnet_id = aws_subnet.my-subnet-1.id
  tags = {
  tags = {
    Name = "HelloWorld"
  }
}

