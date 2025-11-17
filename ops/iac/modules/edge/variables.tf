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

variable "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket (created by data module)."
  type        = string
}

variable "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  type        = string
}

variable "frontend_bucket_regional_domain_name" {
  description = "Regional domain name of the frontend S3 bucket."
  type        = string
}

variable "api_gateway_domain" {
  description = "Domain of the API Gateway execute endpoint (without https://)."
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Stage name for API Gateway to target from CloudFront."
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for custom domain (optional)."
  type        = string
  default     = ""
}

variable "frontend_domain_name" {
  description = "Custom domain name for the frontend (optional)."
  type        = string
  default     = ""
}


