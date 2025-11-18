terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  bucket_name = var.frontend_bucket_name

  custom_domain_enabled = var.frontend_domain_name != ""

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

# Look up the Route53 hosted zone by domain name if custom domain is enabled
data "aws_route53_zone" "this" {
  count        = local.custom_domain_enabled ? 1 : 0
  name         = var.frontend_domain_name
  private_zone = false
}

# Data sources for CloudFront managed cache policies
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "cors_s3" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "simple_cors" {
  name = "Managed-SimpleCORS"
}

# ---------------------------------------------------------------------------
# Optional custom domain configuration (ACM + Route53)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "frontend" {
  count    = local.custom_domain_enabled ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.frontend_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "frontend_certificate_validation" {
  for_each = local.custom_domain_enabled ? {
    for dvo in aws_acm_certificate.frontend[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}

  name            = each.value.name
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this[0].zone_id
  ttl             = 60
  records         = [each.value.value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "frontend" {
  count    = local.custom_domain_enabled ? 1 : 0
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [
    for record in aws_route53_record.frontend_certificate_validation :
    record.fqdn
  ]
}

# Custom response headers policy for CORS with credentials
resource "aws_cloudfront_response_headers_policy" "cors_with_credentials" {
  name    = "${var.project_name}-${var.environment}-cors-credentials"
  comment = "CORS policy with credentials support for API Gateway"

  # CORS is handled by Django middleware (django-cors-headers or custom middleware)
  # CloudFront response headers policy only adds security headers
  # This avoids circular dependency with CloudFront distribution domain

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
  }
}

# Note: When caching is disabled (TTL = 0), cookies cannot be included in cache policy
# Cookies are forwarded to origin via the origin request policy instead
# Using managed "Managed-CachingDisabled" policy for cache policy

# Custom origin request policy for API that forwards cookies and headers
resource "aws_cloudfront_origin_request_policy" "api_with_cookies" {
  name    = "${var.project_name}-${var.environment}-api-origin-request"
  comment = "Origin request policy for API Gateway that forwards cookies and headers"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["CloudFront-Forwarded-Proto", "Origin", "Referer", "X-CSRFToken", "Content-Type", "Accept"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
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
  description = "Custom WAF for Django Habit Tracker Application"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rule 1: Block known malicious IP reputation
  rule {
    name     = "BlockIPReputation"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Rate limit authentication endpoints (Login/Register)
  rule {
    name     = "RateLimitAuth"
    priority = 2

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_auth"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 100 # 100 requests per 5 minutes per IP
        aggregate_key_type = "IP"

        scope_down_statement {
          or_statement {
            statement {
              byte_match_statement {
                search_string         = "/login"
                positional_constraint = "STARTS_WITH"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
            statement {
              byte_match_statement {
                search_string         = "/register"
                positional_constraint = "STARTS_WITH"
                field_to_match {
                  uri_path {}
                }
                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit-auth"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate limit API endpoints (general protection)
  rule {
    name     = "RateLimitAPI"
    priority = 3

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_api"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = 2000 # 2000 requests per 5 minutes per IP
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/api/"
            positional_constraint = "STARTS_WITH"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-rate-limit-api"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: SQL Injection Protection for POST requests
  rule {
    name     = "SQLInjectionProtection"
    priority = 4

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "sql_injection"
        }
      }
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "post"
            positional_constraint = "EXACTLY"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          or_statement {
            statement {
              sqli_match_statement {
                field_to_match {
                  body {
                    oversize_handling = "CONTINUE"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "URL_DECODE"
                }
              }
            }
            statement {
              sqli_match_statement {
                field_to_match {
                  query_string {}
                }
                text_transformation {
                  priority = 0
                  type     = "URL_DECODE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-sqli-protection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: XSS Protection for user input
  rule {
    name     = "XSSProtection"
    priority = 5

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "xss_detected"
        }
      }
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "post"
            positional_constraint = "EXACTLY"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          or_statement {
            statement {
              xss_match_statement {
                field_to_match {
                  body {
                    oversize_handling = "CONTINUE"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "URL_DECODE"
                }
              }
            }
            statement {
              xss_match_statement {
                field_to_match {
                  query_string {}
                }
                text_transformation {
                  priority = 0
                  type     = "URL_DECODE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-xss-protection"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: Size restriction on request body
  rule {
    name     = "SizeRestriction"
    priority = 6

    action {
      block {
        custom_response {
          response_code            = 413
          custom_response_body_key = "request_too_large"
        }
      }
    }

    statement {
      size_constraint_statement {
        comparison_operator = "GT"
        size                = 1048576 # 1MB limit for request body
        field_to_match {
          body {
            oversize_handling = "CONTINUE"
          }
        }
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-size-restriction"
      sampled_requests_enabled   = true
    }
  }

  # Rule 7: Block suspicious User-Agent strings
  rule {
    name     = "BlockSuspiciousUserAgents"
    priority = 7

    action {
      block {
        custom_response {
          response_code            = 403
          custom_response_body_key = "suspicious_user_agent"
        }
      }
    }

    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string         = "sqlmap"
            positional_constraint = "CONTAINS"
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "nikto"
            positional_constraint = "CONTAINS"
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "nmap"
            positional_constraint = "CONTAINS"
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-suspicious-ua"
      sampled_requests_enabled   = true
    }
  }

  # Rule 8: Allow health checks without restrictions
  rule {
    name     = "AllowHealthCheck"
    priority = 8

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        search_string         = "/health"
        positional_constraint = "STARTS_WITH"
        field_to_match {
          uri_path {}
        }
        text_transformation {
          priority = 0
          type     = "LOWERCASE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.environment}-allow-health"
      sampled_requests_enabled   = true
    }
  }

  # Custom response bodies for blocked requests
  custom_response_body {
    key          = "rate_limit_auth"
    content      = "{\"error\": \"Too many authentication attempts. Please try again later.\"}"
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "rate_limit_api"
    content      = "{\"error\": \"Too many requests. Please slow down.\"}"
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "sql_injection"
    content      = "{\"error\": \"Invalid request detected.\"}"
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "xss_detected"
    content      = "{\"error\": \"Invalid content detected.\"}"
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "request_too_large"
    content      = "{\"error\": \"Request body too large. Maximum size is 1MB.\"}"
    content_type = "APPLICATION_JSON"
  }

  custom_response_body {
    key          = "suspicious_user_agent"
    content      = "{\"error\": \"Access denied.\"}"
    content_type = "APPLICATION_JSON"
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

# CloudFront Function to rewrite SPA routes to index.html
resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.project_name}-${var.environment}-spa-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrite SPA routes to index.html for React Router"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Skip processing for API and Django routes entirely
    if (uri.startsWith('/api/') || 
        uri.startsWith('/Login') || 
        uri.startsWith('/Register') || 
        uri.startsWith('/Logout') || 
        uri.startsWith('/Profile') || 
        uri.startsWith('/admin') || 
        uri.startsWith('/health')) {
        return request;
    }
    
    // For React SPA routes: rewrite to /index.html
    if (!uri.includes('.')) {
        request.uri = '/index.html';
    }
    // If URI ends with /, append index.html (only for static files)
    else if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    
    return request;
}
EOT
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "${var.project_name}-${var.environment} distribution"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"
  aliases             = local.custom_domain_enabled ? [var.frontend_domain_name] : []

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

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors_s3.id

    # Apply CloudFront Function to rewrite SPA routes
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # Route API endpoints to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  # Django authentication endpoints - must match nginx.conf configuration
  # Routing strategy:
  #   - /login, /register, /profile (lowercase) → React SPA (from S3)
  #   - /Login/, /Register/, /Profile/ (uppercase) → Django API (form submission endpoints)
  #   - This allows React to render UI while Django handles authentication
  ordered_cache_behavior {
    path_pattern           = "/Login*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Register*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Logout*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Profile*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/admin/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/health/*"
    allowed_methods        = ["HEAD", "GET", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  # Route Django app routes (habits, tasks, etc.) to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/Add-Habit/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Habit-Manager/*"
    allowed_methods        = ["HEAD", "GET", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Habit-Infos/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Habits-Analysis/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/delete-habit/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = local.custom_domain_enabled ? false : true
    acm_certificate_arn            = local.custom_domain_enabled ? aws_acm_certificate_validation.frontend[0].certificate_arn : null
    ssl_support_method             = local.custom_domain_enabled ? "sni-only" : null
    minimum_protocol_version       = local.custom_domain_enabled ? "TLSv1.2_2021" : null
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

resource "aws_route53_record" "frontend_alias" {
  count   = local.custom_domain_enabled ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.frontend_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# ============================================================================
# SSM Parameters for CI/CD Pipelines
# ============================================================================

resource "aws_ssm_parameter" "cloudfront_distribution_id" {
  name        = "/${var.project_name}/${var.environment}/cloudfront/distribution_id"
  description = "CloudFront distribution ID for ${var.environment}"
  type        = "String"
  value       = aws_cloudfront_distribution.this.id
  overwrite   = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "cloudfront_domain_name" {
  name        = "/${var.project_name}/${var.environment}/cloudfront/domain_name"
  description = "CloudFront domain name for ${var.environment}"
  type        = "String"
  value       = aws_cloudfront_distribution.this.domain_name
  overwrite   = true

  tags = local.common_tags
}


