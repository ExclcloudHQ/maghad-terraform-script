terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }

  # Remote backend intentionally omitted for this phase.
  # Initialization sequence (after bucket exists):
  #   1. Create S3 bucket (and optional DynamoDB lock table) manually
  #   2. Uncomment the backend block below (or use -backend-config)
  #   3. terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket         = "maghad-tf-state-dev"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "maghad-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}
