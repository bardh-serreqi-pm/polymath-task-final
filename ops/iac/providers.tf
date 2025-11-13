terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "bardhi-apprentice-final-state"
    key            = "iac/state/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "apprentice-final-terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = "staging"
        Project     = "ApprenticeFinal"
        ManagedBy   = "Terraform"
      }
    )
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================
# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
