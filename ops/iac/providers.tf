terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
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

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = "staging"
        Project     = "ApprenticeFinal"
        Owner       = "Bardh Serreqi"
      }
    )
  }
}

# ============================================================================
# DR Region Provider (us-west-2)
# ============================================================================
provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = "staging"
        Project     = "ApprenticeFinal"
        Owner       = "Bardh Serreqi"
        Region      = "us-west-2"
        Purpose     = "Disaster Recovery"
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
