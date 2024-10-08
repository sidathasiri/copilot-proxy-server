variable "ecs_cluster_name" {
  default = "copilot-proxy-cluster"
}

variable "ecs_service_name" {
  default = "copilot-proxy-service"
}

variable "container_name" {
  default = "copilot-proxy-container"
}

variable "ecr_repo_name" {
  default = "copilot-proxy-repo"
}

variable "task_cpu" {
  default = "256"
}

variable "task_memory" {
  default = "512"
}

variable "desired_count" {
  default = 2
}

variable "max_count" {
  default = 10
}

variable "min_count" {
  default = 2
}

variable "vpc_id" {
  description = "The VPC ID for ECS"
  default = "vpc-ca3604b0"
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS"
  type        = list(string)
  default     = [
    "subnet-8601b7cb",
    "subnet-7a4fac25",
    "subnet-84f214e2"
  ]
}