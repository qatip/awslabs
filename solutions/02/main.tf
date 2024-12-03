terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.53.0"
    }
  }
}

provider "aws" {
  region = "us-west-2" 
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    # new value
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    # original value
    #values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  #instance_type = "t3.small"

  # original entry
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}
