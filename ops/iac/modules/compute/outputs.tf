output "lambda_function_name" {
  description = "Name of the API Lambda function."
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the API Lambda function."
  value       = aws_lambda_function.api.arn
}

output "lambda_security_group_id" {
  description = "Security group ID attached to the Lambda function."
  value       = aws_security_group.lambda.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the API image."
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository for the API image."
  value       = aws_ecr_repository.api.arn
}

output "api_gateway_url" {
  description = "Invoke URL for the API Gateway stage."
  value       = aws_apigatewayv2_stage.api.invoke_url
}

output "api_gateway_domain" {
  description = "Execute API domain (without stage path) for CloudFront origin."
  value       = trimprefix(aws_apigatewayv2_api.api.api_endpoint, "https://")
}

output "api_gateway_id" {
  description = "ID of the API Gateway HTTP API."
  value       = aws_apigatewayv2_api.api.id
}

output "api_gateway_stage_name" {
  description = "Stage name for API Gateway."
  value       = aws_apigatewayv2_stage.api.name
}

output "lambda_log_group_name" {
  description = "CloudWatch log group name for Lambda function."
  value       = aws_cloudwatch_log_group.lambda.name
}

output "api_gateway_log_group_name" {
  description = "CloudWatch log group name for API Gateway execution logs."
  value       = aws_cloudwatch_log_group.api_execution.name
}


