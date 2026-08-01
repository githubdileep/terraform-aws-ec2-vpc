terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend (S3 + DynamoDB lock table).
  # Values are intentionally left out here and supplied at `terraform init`
  # time via -backend-config, so the same code works locally and in CI
  # without hardcoding a bucket name in source control.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}
