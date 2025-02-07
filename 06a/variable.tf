variable "region" {
  description = "location to build resources"
  type        = string
  default     = "us-east-2"
}
variable "az_count" {
  default = 3
}
