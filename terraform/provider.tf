terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # For version 1, local state is used by default.
  # To migrate to S3 remote backend with DynamoDB state locking in the future,
  # see the Remote State section in README.md.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
