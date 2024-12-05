provider "aws" {
  region = var.region
}

resource "aws_instance" "example" {
  ami           = var.ami_map[var.region]
  instance_type = var.size
  count         = var.inst_count

  tags = {
    Name = "terraform-demo-${terraform.workspace}-${format("%02d", count.index + 1)}"
  }
}
