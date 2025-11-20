output "aurora_cluster_id" {
  description = "ID/identifier of the Aurora Serverless cluster."
  value       = aws_rds_cluster.aurora.id
}

output "aurora_cluster_arn" {
  description = "ARN of the Aurora Serverless cluster."
  value       = aws_rds_cluster.aurora.arn
}

output "aurora_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Aurora credentials."
  value       = aws_secretsmanager_secret.aurora_master.arn
}

output "aurora_writer_endpoint" {
  description = "Writer endpoint for Aurora."
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint for Aurora."
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_security_group_id" {
  description = "Security group ID protecting Aurora."
  value       = aws_security_group.aurora.id
}

output "redis_cluster_id" {
  description = "ID of the Redis serverless cache cluster."
  value       = aws_elasticache_serverless_cache.redis.id
}

output "redis_cluster_arn" {
  description = "ARN of the Redis serverless cache cluster."
  value       = aws_elasticache_serverless_cache.redis.arn
}

output "redis_endpoint" {
  description = "Redis serverless endpoint."
  value       = aws_elasticache_serverless_cache.redis.endpoint
}

output "redis_security_group_id" {
  description = "Security group ID protecting Redis."
  value       = aws_security_group.redis.id
}

output "ssm_parameter_arns" {
  description = "ARNs of SSM parameters created for data layer integration."
  value = [
    aws_ssm_parameter.aurora_writer_endpoint.arn,
    aws_ssm_parameter.aurora_reader_endpoint.arn,
    aws_ssm_parameter.redis_endpoint.arn
  ]
}

output "aurora_writer_endpoint_param_name" {
  description = "Name of the SSM parameter containing the Aurora writer endpoint."
  value       = aws_ssm_parameter.aurora_writer_endpoint.name
}

output "aurora_instance_arn" {
  description = "ARN of the Aurora cluster writer instance."
  value       = aws_rds_cluster_instance.aurora.arn
}

output "redis_endpoint_param_name" {
  description = "Name of the SSM parameter containing the Redis endpoint."
  value       = aws_ssm_parameter.redis_endpoint.name
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket."
  value       = aws_s3_bucket.frontend.arn
}

output "frontend_bucket_regional_domain_name" {
  description = "Regional domain name of the frontend S3 bucket."
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}


