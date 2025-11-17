locals {
  bucket_name = var.frontend_bucket_name

  custom_domain_enabled = var.frontend_domain_name != "" && var.route53_zone_id != ""

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
  zone_id         = var.route53_zone_id
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
      items = ["CloudFront-Forwarded-Proto", "Host", "Origin", "Referer", "X-CSRFToken", "Content-Type", "Accept"]
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

  # Route Django authentication and admin routes to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/Login"
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
    path_pattern           = "/register*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Profile/*"
    allowed_methods        = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.api_origin_id
    viewer_protocol_policy = "https-only"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.api_with_cookies.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors_with_credentials.id
  }

  ordered_cache_behavior {
    path_pattern           = "/Logout"
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

  # Custom error responses for SPA routing
  # When a route like /register doesn't exist in S3, return index.html with 200 status
  # This is REQUIRED for React Router (BrowserRouter) to work with S3/CloudFront
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 300
  }

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
  zone_id = var.route53_zone_id
  name    = var.frontend_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}


