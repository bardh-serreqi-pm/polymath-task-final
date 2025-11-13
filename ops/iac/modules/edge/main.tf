locals {
  bucket_name = var.frontend_bucket_name

  common_tags = merge(
    var.tags,
    {
      Component   = "edge"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "edge"
    }
  )
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-${var.environment}-frontend-oac"
  description                       = "Access control for frontend S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.project_name}-${var.environment}-waf"
  description = "Baseline WAF for CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-commonrules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

locals {
  api_origin_id      = "api-gateway-origin"
  frontend_origin_id = "frontend-s3-origin"
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "${var.project_name}-${var.environment} distribution"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  origin {
    domain_name              = var.frontend_bucket_regional_domain_name
    origin_id                = local.frontend_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = var.api_gateway_domain
    origin_id   = local.api_origin_id

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 30
      origin_read_timeout      = 30
    }
    origin_path = "/${var.api_gateway_stage_name}"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.frontend_origin_id
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
    origin_request_policy_id = "413fd1bd-4f22-4681-beca-5e857496ad9f" # Managed-CORS-S3Origin
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = "216adef6-5c7f-47e4-b989-5492eafa07d3" # Managed-CachingDisabled
    origin_request_policy_id   = "088c1a12-3b52-40d3-a960-350dcb7126de" # Managed-AllViewerExceptHostHeader
    response_headers_policy_id = "b69b958a-1b4e-4f23-94e0-5799a1112d87" # Managed-SimpleCORS
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  web_acl_id = aws_wafv2_web_acl.this.arn

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-distribution" })

}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = local.bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${var.frontend_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}


