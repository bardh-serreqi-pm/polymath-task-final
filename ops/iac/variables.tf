# ============================================================================
# TERRAFORM VARIABLES
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "apprentice-final"
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "staging"
    Project     = "ApprenticeFinal"
    Owner       = "Bardh Serreqi"
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.20.16.0/24", "10.20.17.0/24"]
}

variable "db_name" {
  description = "Database name for Aurora Serverless"
  type        = string
  default     = "habittracker"
}

variable "db_master_username" {
  description = "Master username for Aurora Serverless"
  type        = string
  default     = "dbadmin"
}

variable "aurora_min_capacity" {
  description = "Minimum ACUs for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACUs for Aurora Serverless v2"
  type        = number
  default     = 4
}

variable "lambda_image_uri" {
  description = "ECR image URI for the Django Lambda function"
  type        = string
}

variable "lambda_environment" {
  description = "Additional environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "frontend_bucket_name" {
  description = "Optional custom name for the frontend S3 bucket"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for custom domain (optional)"
  type        = string
  default     = ""
}

variable "frontend_domain_name" {
  description = "Custom domain name for the frontend CloudFront distribution (e.g., app.example.com). Leave empty to use the CloudFront URL."
  type        = string
  default     = ""
}

variable "django_secret_key" {
  description = "Django SECRET_KEY (if not provided, will be generated)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "django_debug" {
  description = "Django DEBUG setting"
  type        = string
  default     = "False"
}

variable "django_allowed_hosts" {
  description = "Comma-separated list of allowed hosts for Django"
  type        = string
  default     = "*"
}

