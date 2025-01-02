provider "aws" {
  region = "us-west-2"
}

resource "aws_instance" "example" {
  ami           = "ami-0d08c3b92d0f4250a"
  instance_type = "t2.micro"
  count         = 1

  tags = {
    Name = "terraform-demo-${terraform.workspace}-${format("%02d", count.index + 1)}"
  }
}

output "instance_details" {
  description = "Details of the created instances"
  value = {
    workspace = terraform.workspace
    region    = var.region
    vm_names  = [for instance in aws_instance.example : instance.tags["Name"]]
    size      = aws_instance.example[0].instance_type
    ami       = aws_instance.example[0].ami
  }
}