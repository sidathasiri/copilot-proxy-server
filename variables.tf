variable "ecr_repo_name" {
  default = "copilot-proxy"
}

variable "desired_count" {
  default = 1
}

variable "ami_id" {
  default = "ami-0fff1b9a61dec8a5f"
}

variable "max_count" {
  default = 10
}

variable "min_count" {
  default = 1
}

variable "vpc_id" {
  description = "The VPC ID"
  default = "vpc-ca3604b0"
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
  default     = [
    "subnet-8601b7cb",
    "subnet-7a4fac25",
    "subnet-84f214e2"
  ]
}