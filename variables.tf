# variables.tf
variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}
variable "additional-tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default = {
    application = "xray-poc"
    env         = "development"
  }
}
variable "network_cidr" {
  description = "IP addressing for the network"
  type        = string
}
# Number of tasks en ECS Cluster
variable "app_count" {
  type    = number
  default = 1
}