variable "tag_name" {
  default = "lab-vpc"
}

variable "vpc-cidr" {
  default = "10.1.0.0/16"
}

variable "labname" {
  description = "prefix for lab resources"
  default     = "lab"
}

#map to create subnets : usw2 = US-WEST-2 (oregon) and this is followed by the desired AZ ie az1
variable "pubsubnet" {
  type = map(any)
  default = {
    sub-1 = {
      az   = "usw2-az1"
      cidr = "10.1.1.0/24"
    }
    sub-2 = {
      az   = "usw2-az2"
      cidr = "10.1.2.0/24"
    }
    sub-3 = {
      az   = "usw2-az3"
      cidr = "10.1.3.0/24"
    }
  }
}

variable "privsubnet" {
  type = map(any)
  default = {
    sub-1 = {
      az   = "usw2-az1"
      cidr = "10.1.4.0/24"
    }
    sub-2 = {
      az   = "usw2-az2"
      cidr = "10.1.5.0/24"
    }
    sub-3 = {
      az   = "usw2-az3"
      cidr = "10.1.6.0/24"
    }
  }
}
