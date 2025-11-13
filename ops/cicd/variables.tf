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

variable "ecr_api_repository_url" {
  description = "Full URL of the ECR repository for API container (from IAC outputs)"
  type        = string
}

variable "ecr_web_repository_url" {
  description = "Full URL of the ECR repository for Web container (from IAC outputs)"
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

variable "vpc_id" {
  description = "VPC ID for CodeBuild projects (if needed)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for CodeBuild projects (if needed)"
  type        = list(string)
  default     = []
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for backend deployment (optional)"
  type        = string
  default     = ""
}

variable "frontend_s3_bucket" {
  description = "S3 bucket name for frontend deployment (optional, will be created if not provided)"
  type        = string
  default     = ""
}

variable "cloudfront_invalidation_lambda" {
  description = "Lambda function name for CloudFront cache invalidation (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "ApprenticeFinal"
    ManagedBy = "Terraform"
  }
}

