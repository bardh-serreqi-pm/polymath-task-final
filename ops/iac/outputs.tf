# ============================================================================
# TERRAFORM OUTPUTS
# ============================================================================

# ---------------------------- Network --------------------------------------
output "vpc_id" {
  description = "ID of the VPC created for this environment."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.network.private_subnet_ids
}

# ---------------------------- Compute --------------------------------------
output "lambda_function_name" {
  description = "Name of the Django API Lambda function."
  value       = module.compute.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Django API Lambda function."
  value       = module.compute.lambda_function_arn
}

output "api_ecr_repository_url" {
  description = "ECR repository URL for the Lambda container image."
  value       = module.compute.ecr_repository_url
}

output "api_gateway_url" {
  description = "Invoke URL for API Gateway."
  value       = module.compute.api_gateway_url
}

# ---------------------------- Data -----------------------------------------
output "aurora_secret_arn" {
  description = "Secrets Manager ARN storing Aurora credentials."
  value       = module.data.aurora_secret_arn
}

# ---------------------------- Edge -----------------------------------------
output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = module.data.frontend_bucket_name
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  value       = module.data.frontend_bucket_arn
}

output "frontend_bucket_regional_domain_name" {
  description = "Regional domain name of the frontend S3 bucket."
  value       = module.data.frontend_bucket_regional_domain_name
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution."
  value       = module.edge.cloudfront_distribution_domain
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = module.edge.cloudfront_distribution_id
}

output "frontend_domain_name" {
  description = "Primary domain serving the frontend."
  value       = module.edge.frontend_domain_name
}

# ---------------------------- Observability --------------------------------
output "alerts_sns_topic_arn" {
  description = "SNS topic ARN for alert notifications."
  value       = module.observability.sns_topic_arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

