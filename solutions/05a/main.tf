terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.50"
    }
    
    
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
    ignore_tags { 
    key_prefixes = ["ca-"]
  }
}

module "vpc" {
  source = "./network"

}

terraform {
 backend "s3" {
   bucket         = "tf-remote-state-{your-name}"
   key            = "terraform.tfstate"
   region         = "us-west-2"
 }
}
   