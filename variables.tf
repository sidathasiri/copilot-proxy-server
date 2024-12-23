variable "ecr_repo_name" {
  default = "copilot-proxy"
}

variable "desired_count" {
  default = 1
}

variable "ami_id" {
  default = "ami-0e54671bdf3c8ed8d"
}

variable "max_count" {
  default = 10
}

variable "min_count" {
  default = 1
}

variable "vpc_id" {
  description = "The VPC ID"
  default = "vpc-0689fd46700c51c41"
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
  default     = [
    "subnet-090ea8b99e9962796",
    "subnet-00f79aeba15fb6e24",
    "subnet-04cbee6d70234bca1"
  ]
}