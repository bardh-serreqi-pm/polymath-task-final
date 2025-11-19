# ============================================================================
# Provider Configuration for Data Module
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.us_west_2
      ]
    }
  }
}

