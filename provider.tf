provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "copilot-analyzer-tf-backend"
    key    = "ecs/terraform.tfstate"
    region = "us-east-1"
  }
}
