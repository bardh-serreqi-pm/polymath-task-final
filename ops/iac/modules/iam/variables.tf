variable "project_name" {
  description = "Project name tag value."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., staging, production)."
  type        = string
}

variable "tags" {
  description = "Base tags applied to resources."
  type        = map(string)
  default     = {}
}

variable "iam_user_name" {
  description = "Name of the existing IAM user that should assume the operator role."
  type        = string
  default     = "Apprentice-Final"
}

variable "lambda_function_arn" {
  description = "ARN of the API Lambda function."
  type        = string
}

variable "lambda_log_group_name" {
  description = "CloudWatch log group name for the Lambda function."
  type        = string
}

variable "api_gateway_id" {
  description = "HTTP API Gateway ID."
  type        = string
}

variable "api_gateway_log_group_name" {
  description = "CloudWatch log group name for API Gateway execution logs."
  type        = string
}

variable "aurora_cluster_arn" {
  description = "ARN of the Aurora cluster."
  type        = string
}

variable "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret storing database credentials."
  type        = string
}

variable "redis_cluster_arn" {
  description = "ARN of the ElastiCache Serverless Redis cluster."
  type        = string
}

variable "aurora_instance_arn" {
  description = "ARN of the Aurora cluster writer instance."
  type        = string
}

variable "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  type        = string
}

variable "waf_web_acl_arn" {
  description = "ARN of the WAF web ACL associated with CloudFront."
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic used for alerts."
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "Root prefix for project SSM parameters (e.g., /project/env)."
  type        = string
}

variable "terraform_state_bucket" {
  description = "Name of the Terraform state S3 bucket."
  type        = string
}

variable "terraform_state_lock_table" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
}

variable "backup_vault_primary_arn" {
  description = "ARN of the primary AWS Backup vault."
  type        = string
}

variable "backup_vault_dr_arn" {
  description = "ARN of the DR AWS Backup vault."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository for the Lambda container image."
  type        = string
}


