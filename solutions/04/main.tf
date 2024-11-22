terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.53.0"
    }
  }
}

provider "aws" {
  region = var.deployment_region
}

resource "aws_vpc" "testvpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "Test VPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.testvpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = var.region_az
  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.testvpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = var.region_az
  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_internet_gateway" "labigw" {
  vpc_id = aws_vpc.testvpc.id

  tags = {
    Name = "Lab IGW"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.testvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.labigw.id
  }
  tags = {
    Name = "Public route table"
  }
  depends_on = [aws_internet_gateway.labigw]
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.testvpc.id

  tags = {
    Name = "Private route table"
  }
}

resource "aws_route_table_association" "pub_to_ig" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
  depends_on     = [aws_internet_gateway.labigw]
}

resource "aws_route_table_association" "priv_to_nat" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "internal" {
  name        = "Internal SG"
  description = "SG for internal instances"
  vpc_id      = aws_vpc.testvpc.id

  ingress {
    description = "ALL"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Internal SG"
  }
}

resource "aws_security_group" "external" {
  name        = "External SG"
  description = "SG for front facing instances"
  vpc_id      = aws_vpc.testvpc.id

  ingress {
    description = "ALL"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.2.0/24"]
  }

  ingress {
    description = "SSH"
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
    Name = "External SG"
  }
}

resource "aws_instance" "PrivVM" {
  ami = var.instance_ami
  instance_type = var.ec2_instance_size
  availability_zone = var.region_az
  subnet_id = aws_subnet.private_subnet.id
  associate_public_ip_address = false
  vpc_security_group_ids = ["${aws_security_group.internal.id}"]

  tags = {
    Name = "PrivVM"
  }
  depends_on = [aws_subnet.private_subnet, aws_security_group.internal]
}

resource "aws_instance" "PubVM" {
  ami = var.instance_ami
  instance_type = var.ec2_instance_size
  availability_zone = var.region_az
  subnet_id = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.external.id}"]

  tags = {
    Name = "PubVM"
  }
  depends_on = [aws_subnet.public_subnet, aws_security_group.external]
}
