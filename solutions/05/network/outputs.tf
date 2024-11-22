output "vpc-id" {
  description = "ID of the VPC"
  value       = aws_vpc.lab-vpc.id
}

output "public-subnets" {
  description = "id of public subnets"
  value       = aws_subnet.public-subnet
}

output "private-subnets" {
  description = "id of private subnets"
  value       = aws_subnet.private-subnet
}

output "nat-gateway" {
  description = "id of nat gateway"
  value       = aws_nat_gateway.lab-nat-gw.id
}

output "ec2instance-sg" {
  description = "id of ec2instance security group"
  value = aws_security_group.ec2instance-sg.id
}

output "loadbal-sg" {
  description = "id of loadbal security group"
  value = aws_security_group.loadbal-sg.id
}
