# Monitoring, Logging, and Alerting Implementation

This document describes the complete monitoring, logging, and alerting infrastructure as per the project requirements (Section 5).

## Overview

The observability module implements comprehensive monitoring for all AWS resources in the serverless architecture, including:
- API Gateway
- AWS Lambda
- Aurora Serverless v2 (PostgreSQL)
- ElastiCache Serverless (Redis)

## 1. Logging

### CloudWatch Log Groups

All application logs are sent to CloudWatch Logs with structured naming:

| Component | Log Group | Retention |
|-----------|-----------|-----------|
| Lambda Function | `/aws/lambda/apprentice-final-staging-api` | 7 days |
| API Gateway Execution | `/aws/apigateway/{api-id}` | 7 days |
| API Gateway Access | Custom access logs | 7 days |

### Log Configuration

- **Lambda**: Configured to send all logs (INFO, WARNING, ERROR) to CloudWatch
- **API Gateway**: 
  - Execution logs enabled at INFO level
  - Detailed access logs with request/response details
  - CloudWatch role attached for log writing permissions

## 2. Metrics & Dashboard

### CloudWatch Dashboard

A comprehensive dashboard (`apprentice-final-staging-overview`) displays 9 key metrics across 3 rows:

#### Row 1: API Layer
1. **API Gateway - Status Codes**
   - Total request count (2xx)
   - 4xx client errors
   - 5xx server errors
   - Period: 5 minutes

2. **API Gateway - Latency**
   - Average latency
   - P99 latency (99th percentile)
   - Period: 5 minutes

3. **Lambda - Invocations & Errors**
   - Total invocations
   - Function errors
   - Throttles
   - Period: 5 minutes

#### Row 2: Compute & Database
4. **Lambda - Duration**
   - Average duration
   - Maximum duration
   - P99 duration
   - Period: 5 minutes

5. **Aurora - Database Connections**
   - Average number of active connections
   - Period: 5 minutes

6. **Aurora - CPU Utilization**
   - Average CPU percentage
   - Warning threshold at 80%
   - Period: 5 minutes

#### Row 3: Cache Layer
7. **ElastiCache Redis - Cache Performance**
   - Cache hits (green)
   - Cache misses (red)
   - Period: 5 minutes

8. **ElastiCache Redis - CPU Utilization**
   - Average CPU percentage
   - Warning threshold at 75%
   - Period: 5 minutes

9. **ElastiCache Redis - Memory Usage**
   - Memory usage percentage
   - Critical threshold at 90%
   - Period: 5 minutes

## 3. CloudWatch Alarms

### Required Alarms (Per Project Spec)

#### 1. High 5XX Error Rate (Required)
- **Alarm Name**: `apprentice-final-staging-api-5xx`
- **Description**: Alert when API Gateway 5XX errors exceed 5% over 5 minutes
- **Threshold**: > 5%
- **Evaluation Period**: 1 period of 60 seconds
- **Metric**: API Gateway 5XXError rate
- **Action**: SNS notification

#### 2. High Latency (Required)
- **Alarm Name**: `apprentice-final-staging-api-latency`
- **Description**: Alert when API latency exceeds 500ms
- **Threshold**: > 500ms
- **Evaluation Period**: 1 period of 60 seconds
- **Metric**: API Gateway Latency (Average)
- **Action**: SNS notification

### Additional Alarms (Best Practices)

#### 3. Lambda Function Errors
- **Alarm Name**: `apprentice-final-staging-lambda-errors`
- **Description**: Alert when Lambda errors exceed 5 in a period
- **Threshold**: > 5 errors
- **Evaluation Period**: 2 periods of 60 seconds
- **Metric**: AWS/Lambda Errors (Sum)
- **Action**: SNS notification

#### 4. Lambda Throttles
- **Alarm Name**: `apprentice-final-staging-lambda-throttles`
- **Description**: Alert when Lambda function is throttled
- **Threshold**: > 0
- **Evaluation Period**: 1 period of 60 seconds
- **Metric**: AWS/Lambda Throttles (Sum)
- **Action**: SNS notification

#### 5. Aurora Database Connections
- **Alarm Name**: `apprentice-final-staging-aurora-connections`
- **Description**: Alert when database connections are high
- **Threshold**: > 80 connections
- **Evaluation Period**: 2 periods of 300 seconds
- **Metric**: AWS/RDS DatabaseConnections (Average)
- **Action**: SNS notification

#### 6. Aurora CPU Utilization
- **Alarm Name**: `apprentice-final-staging-aurora-cpu`
- **Description**: Alert when Aurora CPU exceeds 80%
- **Threshold**: > 80%
- **Evaluation Period**: 2 periods of 300 seconds
- **Metric**: AWS/RDS CPUUtilization (Average)
- **Action**: SNS notification

#### 7. Redis CPU Utilization
- **Alarm Name**: `apprentice-final-staging-redis-cpu`
- **Description**: Alert when Redis CPU exceeds 75%
- **Threshold**: > 75%
- **Evaluation Period**: 2 periods of 300 seconds
- **Metric**: AWS/ElastiCache CPUUtilization (Average)
- **Action**: SNS notification

#### 8. Redis Memory Usage
- **Alarm Name**: `apprentice-final-staging-redis-memory`
- **Description**: Alert when Redis memory usage exceeds 90%
- **Threshold**: > 90%
- **Evaluation Period**: 2 periods of 300 seconds
- **Metric**: AWS/ElastiCache DatabaseMemoryUsagePercentage (Average)
- **Action**: SNS notification

## 4. SNS Topic & Email Alerts

### SNS Configuration

- **Topic Name**: `apprentice-final-staging-alerts`
- **Protocol**: Email
- **Endpoint**: Configurable via `alert_email` variable in `terraform.tfvars`

### Email Subscription Setup

1. **Set Email Address**: Update `terraform.tfvars`:
   ```hcl
   alert_email = "your-email@example.com"
   ```

2. **Deploy Infrastructure**:
   ```bash
   cd ops/iac
   terraform apply
   ```

3. **Confirm Subscription**:
   - Check your email inbox
   - Look for "AWS Notification - Subscription Confirmation"
   - Click the confirmation link
   - You will receive "Subscription confirmed!" message

4. **Test Alerts** (Optional):
   - Manually trigger an alarm by causing high error rates
   - Or use AWS console to set an alarm to ALARM state
   - Verify email notification is received

### Email Notification Format

Emails will contain:
- Alarm name and description
- Current state (ALARM, OK, INSUFFICIENT_DATA)
- Threshold that was breached
- Current metric value
- Timestamp
- Link to CloudWatch console

## 5. Configuration

### Terraform Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `alert_email` | Email address for CloudWatch alarms | No | "" (no email) |
| `api_gateway_stage_name` | API Gateway stage for metrics | Yes | "staging" |
| `lambda_function_name` | Lambda function name | Yes | (from module) |
| `aurora_cluster_id` | Aurora cluster identifier | Yes | (from module) |
| `redis_cluster_id` | Redis cluster identifier | Yes | (from module) |

### Module Usage

```hcl
module "observability" {
  source = "./modules/observability"

  project_name           = var.project_name
  environment            = var.environment
  api_gateway_id         = module.compute.api_gateway_id
  api_gateway_stage_name = module.compute.api_gateway_stage_name
  lambda_function_name   = module.compute.lambda_function_name
  aurora_cluster_id      = module.data.aurora_cluster_id
  redis_cluster_id       = module.data.redis_cluster_id
  alert_email            = var.alert_email
  tags                   = local.common_tags
}
```

## 6. Accessing Monitoring

### CloudWatch Dashboard
1. Navigate to CloudWatch console
2. Click "Dashboards" in left menu
3. Select `apprentice-final-staging-overview`
4. View real-time metrics

### CloudWatch Logs
1. Navigate to CloudWatch console
2. Click "Log groups" in left menu
3. Select log group (e.g., `/aws/lambda/apprentice-final-staging-api`)
4. View log streams and entries

### CloudWatch Alarms
1. Navigate to CloudWatch console
2. Click "Alarms" → "All alarms"
3. View alarm states and history
4. Set manual alarm states for testing

## 7. Cost Optimization

- Log retention set to 7 days (adjustable)
- Metrics collected at 5-minute granularity
- Dashboard uses standard metrics (no custom metrics)
- Alarms use evaluation periods to reduce false positives

## 8. Troubleshooting

### No Email Notifications Received

1. **Check SNS subscription status**:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <sns-topic-arn>
   ```
   - Status should be "Confirmed", not "PendingConfirmation"

2. **Check spam folder** for confirmation email

3. **Verify alarm is triggering**:
   - Check alarm history in CloudWatch console
   - Manually set alarm to ALARM state for testing

### Dashboard Not Showing Data

1. **Wait for metrics**: Metrics may take 5-10 minutes to appear after deployment
2. **Verify resources exist**: Check that Lambda, API Gateway, Aurora, and Redis are deployed
3. **Check permissions**: Ensure CloudWatch has permissions to read metrics

### Alarms Not Triggering

1. **Check evaluation periods**: Some alarms require 2 consecutive breaches
2. **Verify threshold values**: Ensure thresholds are appropriate for your workload
3. **Check metric data**: View metric graph to confirm data is being collected

## 9. Maintenance

### Adding New Alarms

1. Edit `ops/iac/modules/observability/main.tf`
2. Add new `aws_cloudwatch_metric_alarm` resource
3. Set `alarm_actions = [aws_sns_topic.alerts.arn]`
4. Run `terraform apply`

### Updating Dashboard

1. Edit `ops/iac/modules/observability/main.tf`
2. Update `dashboard_body` JSON in `aws_cloudwatch_dashboard.main`
3. Run `terraform apply`

### Changing Alert Email

1. Update `alert_email` in `terraform.tfvars`
2. Run `terraform apply`
3. Confirm new subscription via email
4. Old subscription will be automatically removed

## 10. Compliance with Project Requirements

✅ **Logging**: All application logs sent to CloudWatch Logs  
✅ **Metrics Collection**: From API Gateway, Lambda, RDS, ElastiCache  
✅ **Dashboard**: Single comprehensive dashboard with 2xx/4xx/5xx counts, latency, DB connections, cache metrics  
✅ **Alarms**: 8 total alarms (2 required + 6 additional)  
✅ **5XX Error Rate Alarm**: Configured at >5% for 5 minutes  
✅ **High Latency/CPU Alarm**: Multiple alarms for latency and resource utilization  
✅ **SNS Topic**: Created for alert notifications  
✅ **Email Alerts**: Configurable via `alert_email` variable  
✅ **Documentation**: This document provides subscription and testing steps

## 11. Next Steps

1. Set your email address in `terraform.tfvars`
2. Deploy infrastructure with `terraform apply`
3. Confirm email subscription
4. Test an alarm to verify email delivery
5. Customize alarm thresholds for your workload
6. Document alert response procedures in RUNBOOK.md

