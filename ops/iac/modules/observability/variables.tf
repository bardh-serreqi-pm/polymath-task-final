variable "project_name" {
  description = "Project name for tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "tags" {
  description = "Base tags to apply."
  type        = map(string)
  default     = {}
}

variable "api_gateway_id" {
  description = "ID of the API Gateway for monitoring."
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Stage name for API Gateway."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function for monitoring."
  type        = string
}

variable "aurora_cluster_id" {
  description = "Aurora cluster identifier for monitoring."
  type        = string
}

variable "redis_cluster_id" {
  description = "ElastiCache Redis cluster identifier for monitoring."
  type        = string
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications."
  type        = string
  default     = ""
}


