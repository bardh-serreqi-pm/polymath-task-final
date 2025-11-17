locals {
  sns_topic_name = "${var.project_name}-${var.environment}-alerts"
  dashboard_name = "${var.project_name}-${var.environment}-overview"

  common_tags = merge(
    var.tags,
    {
      Component   = "observability"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "observability"
    }
  )
}

data "aws_region" "current" {}

resource "aws_sns_topic" "alerts" {
  name = local.sns_topic_name
  tags = merge(local.common_tags, { Name = local.sns_topic_name })
}

# SSM parameter for SNS topic ARN (for CI/CD notifications)
resource "aws_ssm_parameter" "alerts_sns_topic_arn" {
  name        = "/${var.project_name}/${var.environment}/sns/alerts_topic_arn"
  description = "SNS topic ARN for alerts in ${var.environment}"
  type        = "String"
  value       = aws_sns_topic.alerts.arn
  overwrite   = true

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx"
  alarm_description   = "Alert when API Gateway 5XX errors exceed 5% over 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5

  metric_query {
    id          = "e1"
    label       = "API 5XX Error Rate"
    return_data = true

    expression = "IF(m2 == 0, 0, (m1 / m2) * 100)"
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "5XXError"
      namespace   = "AWS/ApiGateway"
      period      = 60
      stat        = "Sum"
      dimensions = {
        ApiId = var.api_gateway_id
        Stage = var.api_gateway_stage_name
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "Count"
      namespace   = "AWS/ApiGateway"
      period      = 60
      stat        = "Sum"
      dimensions = {
        ApiId = var.api_gateway_id
        Stage = var.api_gateway_stage_name
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-api-latency"
  alarm_description   = "Alert when API latency exceeds 500ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 500
  period              = 60
  statistic           = "Average"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"

  dimensions = {
    ApiId = var.api_gateway_id
    Stage = var.api_gateway_stage_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway 5XX Errors"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "5XXError", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage_name]
          ]
          stat   = "Sum"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Latency"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage_name]
          ]
          stat   = "Average"
          period = 60
        }
      }
    ]
  })
}


