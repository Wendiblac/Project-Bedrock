terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "innovatemart-tfstate"
    key            = "project-bedrock/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "innovatemart-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
