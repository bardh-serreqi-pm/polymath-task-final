variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "apprentice-final"
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "bardh-serreqi-pm"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "polymath-task-final"
}

variable "github_branch" {
  description = "GitHub branch to trigger pipeline"
  type        = string
  default     = "main"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "api_ecr_repository_url" {
  description = "Full URL of the ECR repository for the Lambda container image (from IAC outputs)"
  type        = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket where the frontend build will be uploaded"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  type        = string
}

variable "api_gateway_url" {
  description = "Invoke URL for API Gateway used in health checks"
  type        = string
}

variable "alerts_sns_topic_arn" {
  description = "SNS topic ARN for pipeline notifications"
  type        = string
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "terraform_state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "ApprenticeFinal"
    ManagedBy = "Terraform"
  }
}

