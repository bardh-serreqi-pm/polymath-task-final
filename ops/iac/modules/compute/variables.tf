variable "project_name" {
  description = "Project name for tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "tags" {
  description = "Base tags to apply to resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC where the Lambda should run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda ENIs."
  type        = list(string)
}

variable "aurora_security_group_id" {
  description = "Security group protecting Aurora cluster."
  type        = string
}

variable "redis_security_group_id" {
  description = "Security group protecting Redis cache."
  type        = string
}

variable "aurora_secret_arn" {
  description = "Secrets Manager ARN containing Aurora credentials."
  type        = string
}

variable "aurora_writer_endpoint_param" {
  description = "SSM parameter storing the Aurora writer endpoint."
  type        = string
}

variable "redis_endpoint_param" {
  description = "SSM parameter storing the Redis endpoint."
  type        = string
}

variable "lambda_image_uri" {
  description = "ECR image URI for the API Lambda."
  type        = string
}

variable "lambda_environment" {
  description = "Additional environment variables for the Lambda function."
  type        = map(string)
  default     = {}
}

variable "log_retention_in_days" {
  description = "Retention period for Lambda logs."
  type        = number
  default     = 30
}


