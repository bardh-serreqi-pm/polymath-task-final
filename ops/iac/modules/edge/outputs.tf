output "frontend_bucket_name" {
  description = "Name of the S3 bucket hosting the frontend."
  value       = var.frontend_bucket_name
}

output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF web ACL associated with CloudFront."
  value       = aws_wafv2_web_acl.this.arn
}


