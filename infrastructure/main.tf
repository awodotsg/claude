terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # To use a remote backend (recommended for team use), replace this block:
  # backend "s3" {
  #   bucket = "<your-state-bucket>"
  #   key    = "cityapp/terraform.tfstate"
  #   region = "<region>"
  # }
}

provider "aws" {
  region = var.region
  # Credentials are read from the environment:
  #   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
  # No credential config needed here — set those env vars before running plan/apply.
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
