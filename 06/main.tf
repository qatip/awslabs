terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "REPLACE_WITH_STATE_BUCKET"
    key          = "jenkins-lab/terraform.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "example" {
  bucket = "REPLACE_WITH_TEST_BUCKET"
  tags = {
    Purpose = "JenkinsTerraformLab"
  }
}

output "test_bucket_name" {
  value = aws_s3_bucket.example.id
}
