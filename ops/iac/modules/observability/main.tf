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

# Email subscription to SNS topic (if email provided)
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
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

# Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-errors"
  alarm_description   = "Alert when Lambda function errors exceed threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  period              = 60
  statistic           = "Sum"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Lambda Throttles Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-throttles"
  alarm_description   = "Alert when Lambda function is throttled"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  period              = 60
  statistic           = "Sum"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Aurora Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-connections"
  alarm_description   = "Alert when Aurora database connections are high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  period              = 300
  statistic           = "Average"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# Aurora CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu"
  alarm_description   = "Alert when Aurora CPU utilization exceeds 80%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  period              = 300
  statistic           = "Average"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# ElastiCache Redis CPU Utilization
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu"
  alarm_description   = "Alert when Redis CPU utilization exceeds 75%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 75
  period              = 300
  statistic           = "Average"
  namespace           = "AWS/ElastiCache"
  metric_name         = "CPUUtilization"

  dimensions = {
    CacheClusterId = var.redis_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

# ElastiCache Memory Usage
resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory"
  alarm_description   = "Alert when Redis memory usage exceeds 90%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 90
  period              = 300
  statistic           = "Average"
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"

  dimensions = {
    CacheClusterId = var.redis_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: API Gateway Request Counts (2xx, 4xx, 5xx)
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway - Status Codes"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage_name, { stat = "Sum", label = "Total Requests", color = "#1f77b4" }],
            [".", "4XXError", ".", ".", ".", ".", { stat = "Sum", label = "4xx Errors", color = "#ff7f0e" }],
            [".", "5XXError", ".", ".", ".", ".", { stat = "Sum", label = "5xx Errors", color = "#d62728" }]
          ]
          yAxis = {
            left = {
              label = "Count"
            }
          }
          period  = 300
          stat    = "Sum"
          view    = "timeSeries"
          stacked = false
        }
      },
      # Row 1: API Gateway Latency
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway - Latency"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", var.api_gateway_id, "Stage", var.api_gateway_stage_name, { stat = "Average", label = "Avg Latency" }],
            ["...", { stat = "p99", label = "P99 Latency" }]
          ]
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
          period = 300
          view   = "timeSeries"
        }
      },
      # Row 1: Lambda Metrics
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "Lambda - Invocations & Errors"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, { stat = "Sum", label = "Invocations", color = "#2ca02c" }],
            [".", "Errors", ".", ".", { stat = "Sum", label = "Errors", color = "#d62728" }],
            [".", "Throttles", ".", ".", { stat = "Sum", label = "Throttles", color = "#ff7f0e" }]
          ]
          yAxis = {
            left = {
              label = "Count"
            }
          }
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      # Row 2: Lambda Duration
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Lambda - Duration"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "Average", label = "Avg Duration" }],
            ["...", { stat = "Maximum", label = "Max Duration" }],
            ["...", { stat = "p99", label = "P99 Duration" }]
          ]
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
          period = 300
          view   = "timeSeries"
        }
      },
      # Row 2: Aurora Database Connections
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Aurora - Database Connections"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_id, { stat = "Average", label = "DB Connections" }]
          ]
          yAxis = {
            left = {
              label = "Connections"
            }
          }
          period = 300
          stat   = "Average"
          view   = "timeSeries"
        }
      },
      # Row 2: Aurora CPU Utilization
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Aurora - CPU Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_id, { stat = "Average" }]
          ]
          yAxis = {
            left = {
              label = "Percent"
              max   = 100
            }
          }
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Warning Threshold"
                value = 80
                fill  = "above"
                color = "#ff7f0e"
              }
            ]
          }
        }
      },
      # Row 3: Redis Cache Hit Ratio
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "ElastiCache Redis - Cache Performance"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ElastiCache", "CacheHits", "CacheClusterId", var.redis_cluster_id, { stat = "Sum", label = "Cache Hits", color = "#2ca02c" }],
            [".", "CacheMisses", ".", ".", { stat = "Sum", label = "Cache Misses", color = "#d62728" }]
          ]
          yAxis = {
            left = {
              label = "Count"
            }
          }
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
        }
      },
      # Row 3: Redis CPU Utilization
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "ElastiCache Redis - CPU Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", var.redis_cluster_id, { stat = "Average" }]
          ]
          yAxis = {
            left = {
              label = "Percent"
              max   = 100
            }
          }
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Warning Threshold"
                value = 75
                fill  = "above"
                color = "#ff7f0e"
              }
            ]
          }
        }
      },
      # Row 3: Redis Memory Usage
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          title  = "ElastiCache Redis - Memory Usage"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", var.redis_cluster_id, { stat = "Average" }]
          ]
          yAxis = {
            left = {
              label = "Percent"
              max   = 100
            }
          }
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                label = "Critical Threshold"
                value = 90
                fill  = "above"
                color = "#d62728"
              }
            ]
          }
        }
      }
    ]
  })
}


