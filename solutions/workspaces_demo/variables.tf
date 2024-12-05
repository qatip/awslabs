variable "region" {
  description = "AWS region"
  type        = string
}

variable "inst_count" {
  description = "Number of instances"
  type        = number
}

variable "size" {
  description = "Instance size"
  type        = string
}

variable "ami_map" {
  description = "Mapping of region to AMI ID"
  type        = map(string)
}
