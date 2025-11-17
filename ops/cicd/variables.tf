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
  description = "Full URL of the ECR repository for the Lambda container image (optional, will be read from IAC remote state if not provided)"
  type        = string
  default     = ""
}

variable "frontend_bucket_name" {
  description = "S3 bucket where the frontend build will be uploaded (optional, will be read from IAC remote state if not provided)"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation (optional, will be read from IAC remote state if not provided)"
  type        = string
  default     = ""
}

variable "api_gateway_url" {
  description = "Invoke URL for API Gateway used in health checks (optional, will be read from IAC remote state if not provided)"
  type        = string
  default     = ""
}

variable "lambda_image_default_uri" {
  description = "Fallback Lambda image URI used by the Terraform pipeline when no build artifact is supplied."
  type        = string
  default     = ""
}

variable "alerts_sns_topic_arn" {
  description = "SNS topic ARN for pipeline notifications (optional, will be read from IAC remote state if not provided)"
  type        = string
  default     = ""
}

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "terraform_state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "frontend_domain_name" {
  description = "Custom domain name for the frontend CloudFront distribution (e.g., app.example.com). Leave empty to use the CloudFront URL."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project = "ApprenticeFinal"
    Owner   = "Bardh Serreqi"
  }
}

