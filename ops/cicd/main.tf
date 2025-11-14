# ============================================================================
# AWS PROVIDER CONFIGURATION
# ============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      var.tags,
      {
        Environment = var.environment
        Project     = "ApprenticeFinal"
        ManagedBy   = "Terraform"
      }
    )
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Remote state data source to read IAC module outputs
data "terraform_remote_state" "iac" {
  backend = "s3"

  config = {
    bucket         = var.terraform_state_bucket
    key            = "iac/state/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.terraform_state_lock_table
    encrypt        = true
  }
}

# Local values to use remote state outputs when variables are not provided
locals {
  api_gateway_url            = var.api_gateway_url != "" ? var.api_gateway_url : try(data.terraform_remote_state.iac.outputs.api_gateway_url, "")
  api_ecr_repository_url     = var.api_ecr_repository_url != "" ? var.api_ecr_repository_url : try(data.terraform_remote_state.iac.outputs.api_ecr_repository_url, "")
  frontend_bucket_name       = var.frontend_bucket_name != "" ? var.frontend_bucket_name : try(data.terraform_remote_state.iac.outputs.frontend_bucket_name, "")
  cloudfront_distribution_id = var.cloudfront_distribution_id != "" ? var.cloudfront_distribution_id : try(data.terraform_remote_state.iac.outputs.cloudfront_distribution_id, "")
  alerts_sns_topic_arn       = var.alerts_sns_topic_arn != "" ? var.alerts_sns_topic_arn : try(data.terraform_remote_state.iac.outputs.alerts_sns_topic_arn, "")
  lambda_image_default_uri   = var.lambda_image_default_uri != "" ? var.lambda_image_default_uri : try("${data.terraform_remote_state.iac.outputs.api_ecr_repository_url}:latest", "")
}

# ============================================================================
# PIPELINE-SPECIFIC RESOURCES ONLY
# ============================================================================
# This module ONLY creates resources required for CodeBuild and CodePipeline
# All infrastructure resources (ECR, SNS, etc.) must be created in ops/iac

# S3 Bucket for Pipeline Artifacts (Required by CodePipeline)
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.project_name}-pipeline-artifacts-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-pipeline-artifacts-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# GitHub Connection for CodePipeline (Required for source stage)
resource "aws_codestarconnections_connection" "github" {
  name          = "${var.project_name}-git"
  provider_type = "GitHub"
}
