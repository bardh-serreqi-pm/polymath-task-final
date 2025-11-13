# ============================================================================
# TERRAFORM VARIABLES
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "habit-tracker"
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

