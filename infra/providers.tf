# Map 2a · Which tools Terraform needs (aws, random) and where the inventory
# notebook (state) is kept: the S3 filing cabinet from step 0.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "s3" {}
}

# Map 2a / 5 · The city (eu-north-1) and the name tags on all the furniture (E4).
provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project     = "voting-app"
      Environment = var.env
      Owner       = var.name_prefix
    }
  }
}
