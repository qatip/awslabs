terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.53.0"
    }
  }
}

provider "aws" {
  region = var.region
}


resource "aws_vpc" "labvpc" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "lab_vpc"
  }
}

resource "aws_internet_gateway" "labigw" {
  vpc_id = aws_vpc.labvpc.id
  tags = {
    Name = "lab_igw"
  }
}

resource "aws_subnet" "publicsubnet" {
  vpc_id     = aws_vpc.labvpc.id
  cidr_block = "10.1.10.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet"
  }
}

data "aws_availability_zones" "azlist" {
  state = "available"
}

resource "aws_subnet" "privatesubnets" {
  count             = var.az_count
  cidr_block        = cidrsubnet(aws_vpc.labvpc.cidr_block, 8, count.index + 1)
  availability_zone = data.aws_availability_zones.azlist.names[count.index]
  vpc_id            = aws_vpc.labvpc.id
  tags = {
    Name = "private_subnet_${count.index + 1}"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.labvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.labigw.id
  }
  tags = {
    Name = "public_route"
  }
}

resource "aws_eip" "static_ip" {
  vpc = true
}

resource "aws_nat_gateway" "labnatgw" {
  allocation_id = aws_eip.static_ip.id
  subnet_id     = aws_subnet.publicsubnet.id
  tags = {
    Name = "lab_nat_gw"
  }
  depends_on = [aws_internet_gateway.labigw, aws_eip.static_ip]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.labvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.labnatgw.id
  }
  tags = {
    Name = "private_route"
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.publicsubnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_rta" {
  count          = var.az_count
  subnet_id      = aws_subnet.privatesubnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

