  resource "aws_vpc" "lab-vpc" {
  cidr_block = var.vpc-cidr

  tags = {
    Name = var.tag_name
  }
}

resource "aws_subnet" "public-subnet" {
  for_each = var.pubsubnet

  availability_zone_id = each.value["az"]
  cidr_block           = each.value["cidr"]
  vpc_id               = aws_vpc.lab-vpc.id

  tags = {
    Name = "${var.labname}-public-${each.key}"
  }
}

resource "aws_subnet" "private-subnet" {
  for_each = var.privsubnet

  availability_zone_id = each.value["az"]
  cidr_block           = each.value["cidr"]
  vpc_id               = aws_vpc.lab-vpc.id

  tags = {
    Name = "${var.labname}-private-${each.key}"
  }
}

resource "aws_eip" "static-ip" {
  vpc = true
  tags = {
    Name = "NAT GW Static IP"
  }
}

resource "aws_nat_gateway" "lab-nat-gw" {
  allocation_id = aws_eip.static-ip.id
  subnet_id     = aws_subnet.public-subnet["${keys(var.pubsubnet)[0]}"].id
  tags = {
    Name = "Lab-nat-gw"
  }
  depends_on = [aws_internet_gateway.lab-igw, aws_eip.static-ip, aws_vpc.lab-vpc]
}

resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.lab-vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lab-nat-gw.id
  }

  tags = {
    Name = "lab-private-route"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.lab-vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab-igw.id
  }

  tags = {
    Name = "lab-public-route"
  }
}

resource "aws_internet_gateway" "lab-igw" {
  vpc_id = aws_vpc.lab-vpc.id
  tags = {
    Name = "Lab-IGW"
  }
  depends_on = [aws_vpc.lab-vpc]
}

resource "aws_security_group" "ec2instance-sg" {
  name = "instances"
  vpc_id = aws_vpc.lab-vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.loadbal-sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ec2instances-sg"
  }
}

resource "aws_security_group" "loadbal-sg" {
  name = "loadbalancer"
  vpc_id = aws_vpc.lab-vpc.id
  ingress {
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
    Name = "loadbalancer-sg"
  }
}

resource "aws_route_table_association" "public-to-ig" {
  for_each = var.pubsubnet
  subnet_id      = aws_subnet.public-subnet[each.key].id
  route_table_id = aws_route_table.public-route-table.id
 }

resource "aws_route_table_association" "private-to-nat" {
  for_each = var.privsubnet
  subnet_id     = aws_subnet.private-subnet[each.key].id
  route_table_id = aws_route_table.private-route-table.id
}
