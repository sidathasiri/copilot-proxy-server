provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {
    bucket = "copilot-usage-analyzer-tf-backend"
    key    = "copilot-proxy-server/terraform.tfstate"
    region = "eu-central-1"
  }
}
