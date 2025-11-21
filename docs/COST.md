# Cost Analysis

## Table of Contents

- [Overview](#overview)
- [Cost Estimation Methodology](#cost-estimation-methodology)
- [Resource Configuration Mapping](#resource-configuration-mapping)
- [Monthly Cost Breakdown](#monthly-cost-breakdown)
- [Cost by Service](#cost-by-service)
- [AWS Pricing Calculator Configuration](#aws-pricing-calculator-configuration)
- [Cost Optimization Strategies](#cost-optimization-strategies)
- [Budget Recommendations](#budget-recommendations)

---

## Overview

This document provides a comprehensive cost analysis for the Habit Tracker application infrastructure deployed on AWS using a serverless architecture.

**Architecture**: Option B - Serverless  
**Primary Region**: us-east-1 (N. Virginia)  
**DR Region**: us-west-2 (Oregon)  
**Environment**: Staging (Production costs will be similar)

**Estimated Monthly Cost (Staging)**: $180-220 USD  
**Estimated Monthly Cost (Production)**: $350-450 USD

---

## Cost Estimation Methodology

### Assumptions

**Traffic Estimates (Staging Environment)**:
- **API Requests**: 10,000 requests/day (average)
- **Frontend Requests**: 50,000 requests/day (average)
- **Data Transfer Out**: 10 GB/month
- **Database Size**: 5 GB (Aurora)
- **Cache Size**: 1-2 GB (ElastiCache Serverless)
- **S3 Storage**: 1 GB (frontend static files)
- **Log Ingestion**: 5 GB/month

**Production Estimates**:
- **API Requests**: 100,000 requests/day
- **Frontend Requests**: 500,000 requests/day
- **Data Transfer Out**: 100 GB/month
- **Database Size**: 50 GB
- **Cache Size**: 5-10 GB
- **S3 Storage**: 10 GB
- **Log Ingestion**: 50 GB/month

### Pricing Sources

- AWS Pricing Calculator: https://calculator.aws/
- AWS Pricing Documentation: https://aws.amazon.com/pricing/
- Pricing as of: November 2024
- Region: us-east-1 (N. Virginia) - Primary
- Region: us-west-2 (Oregon) - DR

---

## Resource Configuration Mapping

This section maps all resources with their exact configurations for use in the AWS Pricing Calculator.

### 1. Compute Services

#### AWS Lambda

**Configuration**:
- **Function Name**: `apprentice-final-staging-api`
- **Runtime**: Container Image (Docker)
- **Memory**: 1024 MB
- **Timeout**: 60 seconds
- **Architecture**: x86_64
- **VPC Configuration**: Yes (private subnets)
- **Reserved Concurrency**: None
- **Provisioned Concurrency**: None

**Usage (Staging)**:
- Requests: 10,000/day × 30 = 300,000 requests/month
- Average Duration: 500ms (0.5 seconds)
- Compute: 300,000 × 1024 MB × 0.5s = 153,600,000 MB-seconds = 153.6 GB-seconds

**Usage (Production)**:
- Requests: 100,000/day × 30 = 3,000,000 requests/month
- Average Duration: 500ms
- Compute: 3,000,000 × 1024 MB × 0.5s = 1,536,000,000 MB-seconds = 1,536 GB-seconds

**Pricing Calculator Entry**:
- Service: AWS Lambda
- Region: US East (N. Virginia)
- Requests: 300,000/month (staging), 3,000,000/month (production)
- Duration: 500ms average
- Memory: 1024 MB
- Architecture: x86_64

#### API Gateway (HTTP API)

**Configuration**:
- **API Type**: HTTP API
- **Protocol**: HTTPS
- **Stage**: `staging`
- **Auto Deploy**: Enabled
- **Access Logging**: Enabled (CloudWatch Logs)
- **Default Route**: Lambda integration

**Usage (Staging)**:
- API Calls: 10,000/day × 30 = 300,000 requests/month

**Usage (Production)**:
- API Calls: 100,000/day × 30 = 3,000,000 requests/month

**Pricing Calculator Entry**:
- Service: Amazon API Gateway
- API Type: HTTP API
- Region: US East (N. Virginia)
- Requests: 300,000/month (staging), 3,000,000/month (production)

### 2. Data Services

#### Aurora Serverless v2 (PostgreSQL)

**Configuration**:
- **Engine**: Aurora PostgreSQL
- **Engine Version**: 16.1
- **Min Capacity**: 0.5 ACU
- **Max Capacity**: 4 ACU
- **Storage**: Encrypted (KMS)
- **Backup Retention**: 7 days
- **Multi-AZ**: Yes (automatic)
- **Region**: us-east-1

**Usage (Staging)**:
- Average ACU: 1.0 ACU (idle: 0.5, peak: 2.0)
- Storage: 5 GB
- I/O Requests: ~500,000/month

**Usage (Production)**:
- Average ACU: 2.5 ACU (idle: 1.0, peak: 4.0)
- Storage: 50 GB
- I/O Requests: ~5,000,000/month

**Pricing Calculator Entry**:
- Service: Amazon Aurora
- Engine: PostgreSQL
- Deployment: Serverless v2
- Region: US East (N. Virginia)
- Min ACU: 0.5
- Max ACU: 4.0
- Average ACU: 1.0 (staging), 2.5 (production)
- Storage: 5 GB (staging), 50 GB (production)
- Backup Storage: 10 GB (staging), 100 GB (production)

#### ElastiCache Serverless (Redis)

**Configuration**:
- **Engine**: Redis
- **Mode**: Serverless
- **Data Storage Min**: 1 GB
- **Data Storage Max**: 10 GB
- **Multi-AZ**: Yes (automatic)
- **TLS**: Enabled (required)
- **Snapshot Retention**: 1 snapshot
- **Region**: us-east-1

**Usage (Staging)**:
- Average Storage: 1.5 GB
- Requests: ~1,000,000/month

**Usage (Production)**:
- Average Storage: 7 GB
- Requests: ~10,000,000/month

**Pricing Calculator Entry**:
- Service: Amazon ElastiCache
- Engine: Redis
- Mode: Serverless
- Region: US East (N. Virginia)
- Data Storage: 1.5 GB average (staging), 7 GB average (production)
- Min Storage: 1 GB
- Max Storage: 10 GB

### 3. Storage Services

#### S3 (Frontend Static Hosting)

**Configuration**:
- **Bucket**: `apprentice-final-staging-frontend`
- **Storage Class**: Standard
- **Versioning**: Enabled
- **Encryption**: SSE-S3 (default)
- **Public Access**: Blocked (CloudFront OAC only)
- **Lifecycle Policies**: None
- **Replication**: Cross-region to us-west-2 (DR)

**Usage (Staging)**:
- Storage: 1 GB
- PUT Requests: ~100/month (deployments)
- GET Requests: ~50,000/month (via CloudFront)
- Data Transfer: Included in CloudFront

**Usage (Production)**:
- Storage: 10 GB
- PUT Requests: ~500/month
- GET Requests: ~500,000/month
- Data Transfer: Included in CloudFront

**Pricing Calculator Entry**:
- Service: Amazon S3
- Region: US East (N. Virginia)
- Storage: 1 GB (staging), 10 GB (production)
- Storage Class: Standard
- PUT Requests: 100/month (staging), 500/month (production)
- GET Requests: 50,000/month (staging), 500,000/month (production)

#### S3 Cross-Region Replication (DR)

**Configuration**:
- **Source Region**: us-east-1
- **Destination Region**: us-west-2
- **Destination Storage Class**: STANDARD_IA
- **Replication Time Control**: 15 minutes RPO
- **Storage**: 1 GB (staging), 10 GB (production)

**Pricing Calculator Entry**:
- Service: Amazon S3
- Region: US West (Oregon)
- Storage: 1 GB (staging), 10 GB (production)
- Storage Class: Standard-IA
- Replication: Cross-region from us-east-1

### 4. Network Services

#### CloudFront

**Configuration**:
- **Distribution Type**: Web
- **Origins**: 
  - S3 bucket (frontend)
  - API Gateway (API)
- **Price Class**: Use all edge locations (best performance)
- **SSL/TLS**: SNI (free)
- **Custom Domain**: Yes (ACM certificate)
- **WAF**: Attached
- **CloudFront Functions**: Yes (URL rewriting)

**Usage (Staging)**:
- Data Transfer Out: 10 GB/month
- HTTPS Requests: 50,000/month
- Cache Hit Ratio: 80%

**Usage (Production)**:
- Data Transfer Out: 100 GB/month
- HTTPS Requests: 500,000/month
- Cache Hit Ratio: 85%

**Pricing Calculator Entry**:
- Service: Amazon CloudFront
- Data Transfer Out: 10 GB/month (staging), 100 GB/month (production)
- HTTPS Requests: 50,000/month (staging), 500,000/month (production)
- Price Class: Use all edge locations

#### NAT Gateway

**Configuration**:
- **Type**: NAT Gateway
- **Availability Zone**: Multi-AZ (2 NAT Gateways)
- **Region**: us-east-1
- **Data Transfer**: Outbound to internet

**Usage (Staging)**:
- Hours: 730 hours/month (always on)
- Data Processed: 10 GB/month

**Usage (Production)**:
- Hours: 730 hours/month
- Data Processed: 100 GB/month

**Pricing Calculator Entry**:
- Service: Amazon VPC
- NAT Gateway: 2 gateways (for HA)
- Region: US East (N. Virginia)
- Hours: 730/month per gateway
- Data Processed: 10 GB/month (staging), 100 GB/month (production)

#### Data Transfer

**Configuration**:
- **Outbound to Internet**: From NAT Gateway
- **Inter-AZ Transfer**: Minimal (serverless)
- **Cross-Region**: Backup replication

**Usage (Staging)**:
- NAT Gateway Outbound: 10 GB/month
- Cross-Region (Backup): 10 GB/month

**Usage (Production)**:
- NAT Gateway Outbound: 100 GB/month
- Cross-Region (Backup): 100 GB/month

**Pricing Calculator Entry**:
- Service: Data Transfer
- Outbound to Internet: 10 GB/month (staging), 100 GB/month (production)
- Cross-Region: 10 GB/month (staging), 100 GB/month (production)

### 5. Security Services

#### WAF (Web Application Firewall)

**Configuration**:
- **Web ACL**: Custom rules (no AWS Managed Rules)
- **Scope**: CloudFront
- **Region**: Global (CloudFront)
- **Rules**: Custom application-specific rules

**Usage (Staging)**:
- Web ACL: 1
- Rule Evaluations: 300,000 requests/month

**Usage (Production)**:
- Web ACL: 1
- Rule Evaluations: 3,000,000 requests/month

**Pricing Calculator Entry**:
- Service: AWS WAF
- Web ACL: 1
- Rule Evaluations: 300,000/month (staging), 3,000,000/month (production)
- Region: Global (CloudFront)

#### Secrets Manager

**Configuration**:
- **Secrets**: 1 secret (Aurora master credentials)
- **Region**: us-east-1
- **Rotation**: Not configured

**Usage (Staging/Production)**:
- Secrets: 1

**Pricing Calculator Entry**:
- Service: AWS Secrets Manager
- Region: US East (N. Virginia)
- Secrets: 1

#### ACM (Certificate Manager)

**Configuration**:
- **Certificates**: 1 (custom domain)
- **Region**: us-east-1 (CloudFront)
- **Validation**: DNS

**Usage (Staging/Production)**:
- Certificates: 1 (free)

**Pricing Calculator Entry**:
- Service: AWS Certificate Manager
- Region: US East (N. Virginia)
- Certificates: 1 (free)

### 6. Observability Services

#### CloudWatch Logs

**Configuration**:
- **Log Groups**:
  - `/aws/lambda/apprentice-final-staging-api` (30 days retention)
  - `/aws/apigateway/apprentice-final-staging-http-api` (30 days retention)
- **Region**: us-east-1

**Usage (Staging)**:
- Ingestion: 5 GB/month
- Storage: 5 GB (average)

**Usage (Production)**:
- Ingestion: 50 GB/month
- Storage: 50 GB (average)

**Pricing Calculator Entry**:
- Service: Amazon CloudWatch Logs
- Region: US East (N. Virginia)
- Data Ingestion: 5 GB/month (staging), 50 GB/month (production)
- Storage: 5 GB (staging), 50 GB (production)
- Retention: 30 days

#### CloudWatch Metrics

**Configuration**:
- **Custom Metrics**: ~10 metrics
- **Standard Metrics**: Included (free)
- **Alarms**: 8 alarms

**Usage (Staging/Production)**:
- Custom Metrics: 10
- Alarms: 8

**Pricing Calculator Entry**:
- Service: Amazon CloudWatch
- Region: US East (N. Virginia)
- Custom Metrics: 10
- Metric Alarms: 8

#### SNS (Simple Notification Service)

**Configuration**:
- **Topics**: 1 topic (alerts)
- **Subscriptions**: 1 email subscription
- **Region**: us-east-1

**Usage (Staging/Production)**:
- Topics: 1
- Email Notifications: Free

**Pricing Calculator Entry**:
- Service: Amazon SNS
- Region: US East (N. Virginia)
- Topics: 1 (free)
- Email Notifications: Free

### 7. CI/CD Services

#### CodePipeline

**Configuration**:
- **Pipelines**: 3 pipelines
  - Terraform Pipeline
  - Backend Pipeline
  - Frontend Pipeline
- **Region**: us-east-1

**Usage (Staging/Production)**:
- Active Pipelines: 3
- Executions: ~10/month per pipeline = 30 total

**Pricing Calculator Entry**:
- Service: AWS CodePipeline
- Region: US East (N. Virginia)
- Active Pipelines: 3
- Pipeline Executions: 30/month

#### CodeBuild

**Configuration**:
- **Build Projects**: 3 projects
- **Compute Type**: Linux (3 GB memory, 2 vCPUs)
- **Build Minutes**: ~60 minutes/month (staging), ~120 minutes/month (production)

**Usage (Staging)**:
- Build Minutes: 60/month
- Compute: Linux 3 GB

**Usage (Production)**:
- Build Minutes: 120/month
- Compute: Linux 3 GB

**Pricing Calculator Entry**:
- Service: AWS CodeBuild
- Region: US East (N. Virginia)
- Compute Type: Linux (3 GB memory, 2 vCPUs)
- Build Minutes: 60/month (staging), 120/month (production)

#### ECR (Elastic Container Registry)

**Configuration**:
- **Repositories**: 1 repository
- **Image Storage**: ~1 GB
- **Image Scanning**: Enabled (on push)
- **Region**: us-east-1

**Usage (Staging/Production)**:
- Storage: 1 GB
- Data Transfer: Minimal (internal)

**Pricing Calculator Entry**:
- Service: Amazon ECR
- Region: US East (N. Virginia)
- Storage: 1 GB
- Image Scanning: Enabled

### 8. Backup Services

#### AWS Backup

**Configuration**:
- **Backup Vaults**: 2 vaults (primary + DR)
- **Backup Plan**: 1 plan
  - Hourly backups (7-day retention)
  - Daily backups (90-day retention)
- **Resources**: Aurora cluster
- **Cross-Region Copy**: Yes (us-west-2)

**Usage (Staging)**:
- Backup Storage (Primary): 10 GB
- Backup Storage (DR): 10 GB
- Backup Operations: ~720/month (hourly) + 30/month (daily)

**Usage (Production)**:
- Backup Storage (Primary): 100 GB
- Backup Storage (DR): 100 GB
- Backup Operations: ~720/month (hourly) + 30/month (daily)

**Pricing Calculator Entry**:
- Service: AWS Backup
- Region: US East (N. Virginia)
- Backup Storage: 10 GB (staging), 100 GB (production)
- Backup Operations: 750/month
- Cross-Region Copy: Yes (us-west-2)
- DR Region Storage: 10 GB (staging), 100 GB (production)

### 9. DNS Services

#### Route53

**Configuration**:
- **Hosted Zones**: 1 hosted zone
- **Health Checks**: 1 health check
- **Records**: 
  - A record (alias to CloudFront)
  - Failover routing (primary/secondary)
- **Queries**: ~10,000/month

**Usage (Staging/Production)**:
- Hosted Zones: 1
- Health Checks: 1
- Queries: 10,000/month

**Pricing Calculator Entry**:
- Service: Amazon Route53
- Hosted Zones: 1
- Health Checks: 1
- Queries: 10,000/month

### 10. IAM & Other Services

#### SSM Parameter Store

**Configuration**:
- **Parameters**: ~15 parameters
- **Types**: String, SecureString
- **Region**: us-east-1

**Usage (Staging/Production)**:
- Standard Parameters: 14 (free)
- Advanced Parameters: 1 SecureString (free tier: 10,000)

**Pricing Calculator Entry**:
- Service: AWS Systems Manager Parameter Store
- Region: US East (N. Virginia)
- Standard Parameters: 14 (free)
- Advanced Parameters: 1 (within free tier)

---

## Monthly Cost Breakdown

### Staging Environment

| Service Category | Service | Configuration | Monthly Cost (USD) | Notes |
|-----------------|---------|---------------|-------------------|-------|
| **Compute** | Lambda | 1024 MB, 300K requests | $0.31 | Free tier: 1M requests, 400K GB-seconds |
| | API Gateway | HTTP API, 300K requests | $0.30 | $1.00 per 1M requests |
| **Data** | Aurora Serverless v2 | 0.5-4 ACU, avg 1.0 ACU, 5 GB | $87.60 | $0.12/ACU-hour × 1.0 × 730 hours |
| | ElastiCache Serverless | 1-10 GB, avg 1.5 GB | $136.88 | $0.125/GB-hour × 1.5 × 730 hours |
| **Storage** | S3 | 1 GB Standard | $0.02 | $0.023/GB-month |
| | S3 Replication (DR) | 1 GB Standard-IA | $0.01 | $0.0125/GB-month |
| **Network** | CloudFront | 10 GB transfer, 50K requests | $0.00 | Free tier: 1 TB transfer |
| | NAT Gateway | 2 gateways, 10 GB data | $65.70 | $0.045/hour × 2 × 730 + $0.045/GB × 10 |
| | Data Transfer | 10 GB outbound | $0.90 | $0.09/GB |
| **Security** | WAF | 1 Web ACL, 300K evaluations | $5.18 | $5.00 + $0.60/1M × 0.3 |
| | Secrets Manager | 1 secret | $0.40 | $0.40/secret/month |
| | ACM | 1 certificate | $0.00 | Free |
| **Observability** | CloudWatch Logs | 5 GB ingestion, 5 GB storage | $0.15 | Free tier: 5 GB ingestion |
| | CloudWatch Metrics | 10 custom metrics, 8 alarms | $4.00 | $0.30/metric + $0.10/alarm |
| | SNS | 1 topic, email | $0.00 | Free |
| **CI/CD** | CodePipeline | 3 pipelines | $2.00 | First free, $1.00 each additional |
| | CodeBuild | 60 minutes, Linux 3GB | $0.30 | $0.005/minute |
| | ECR | 1 GB storage | $0.10 | $0.10/GB-month |
| **Backup** | AWS Backup | 10 GB primary, 10 GB DR | $1.90 | $0.095/GB-month × 20 GB |
| **DNS** | Route53 | 1 zone, 1 health check, 10K queries | $0.50 | $0.50/zone + $0.50/health check |
| **Total** | | | **$206.25** | |

### Production Environment (Estimated)

| Service Category | Service | Configuration | Monthly Cost (USD) | Notes |
|-----------------|---------|---------------|-------------------|-------|
| **Compute** | Lambda | 1024 MB, 3M requests | $3.07 | $0.20/1M requests + compute |
| | API Gateway | HTTP API, 3M requests | $3.00 | $1.00 per 1M requests |
| **Data** | Aurora Serverless v2 | 0.5-4 ACU, avg 2.5 ACU, 50 GB | $219.00 | $0.12/ACU-hour × 2.5 × 730 hours |
| | ElastiCache Serverless | 1-10 GB, avg 7 GB | $638.75 | $0.125/GB-hour × 7 × 730 hours |
| **Storage** | S3 | 10 GB Standard | $0.23 | $0.023/GB-month |
| | S3 Replication (DR) | 10 GB Standard-IA | $0.13 | $0.0125/GB-month |
| **Network** | CloudFront | 100 GB transfer, 500K requests | $0.00 | Free tier: 1 TB transfer |
| | NAT Gateway | 2 gateways, 100 GB data | $69.30 | $0.045/hour × 2 × 730 + $0.045/GB × 100 |
| | Data Transfer | 100 GB outbound | $9.00 | $0.09/GB |
| **Security** | WAF | 1 Web ACL, 3M evaluations | $6.80 | $5.00 + $0.60/1M × 3 |
| | Secrets Manager | 1 secret | $0.40 | $0.40/secret/month |
| | ACM | 1 certificate | $0.00 | Free |
| **Observability** | CloudWatch Logs | 50 GB ingestion, 50 GB storage | $24.00 | $0.50/GB after 5 GB free |
| | CloudWatch Metrics | 10 custom metrics, 8 alarms | $4.00 | $0.30/metric + $0.10/alarm |
| | SNS | 1 topic, email | $0.00 | Free |
| **CI/CD** | CodePipeline | 3 pipelines | $2.00 | First free, $1.00 each additional |
| | CodeBuild | 120 minutes, Linux 3GB | $0.60 | $0.005/minute |
| | ECR | 1 GB storage | $0.10 | $0.10/GB-month |
| **Backup** | AWS Backup | 100 GB primary, 100 GB DR | $19.00 | $0.095/GB-month × 200 GB |
| **DNS** | Route53 | 1 zone, 1 health check, 10K queries | $0.50 | $0.50/zone + $0.50/health check |
| **Total** | | | **$996.88** | |

---

## Cost by Service

### Top Cost Drivers (Staging)

1. **ElastiCache Serverless**: $136.88 (66%)
2. **Aurora Serverless v2**: $87.60 (42%)
3. **NAT Gateway**: $65.70 (32%)
4. **CloudWatch Metrics**: $4.00 (2%)
5. **Other Services**: $12.07 (6%)

### Top Cost Drivers (Production)

1. **ElastiCache Serverless**: $638.75 (64%)
2. **Aurora Serverless v2**: $219.00 (22%)
3. **NAT Gateway**: $69.30 (7%)
4. **CloudWatch Logs**: $24.00 (2%)
5. **Other Services**: $45.83 (5%)

---

## AWS Pricing Calculator Configuration

### Step-by-Step Instructions

1. **Go to AWS Pricing Calculator**: https://calculator.aws/
2. **Create New Estimate**: Click "Create estimate"
3. **Add Services**: Add each service below with the specified configuration

### Service-by-Service Configuration

#### 1. AWS Lambda
- **Service**: AWS Lambda
- **Region**: US East (N. Virginia)
- **Requests**: 300,000/month (staging), 3,000,000/month (production)
- **Duration**: 500ms average
- **Memory**: 1024 MB
- **Architecture**: x86_64

#### 2. Amazon API Gateway
- **Service**: Amazon API Gateway
- **API Type**: HTTP API
- **Region**: US East (N. Virginia)
- **Requests**: 300,000/month (staging), 3,000,000/month (production)

#### 3. Amazon Aurora
- **Service**: Amazon Aurora
- **Engine**: PostgreSQL
- **Deployment**: Serverless v2
- **Region**: US East (N. Virginia)
- **Min ACU**: 0.5
- **Max ACU**: 4.0
- **Average ACU**: 1.0 (staging), 2.5 (production)
- **Storage**: 5 GB (staging), 50 GB (production)
- **Backup Storage**: 10 GB (staging), 100 GB (production)

#### 4. Amazon ElastiCache
- **Service**: Amazon ElastiCache
- **Engine**: Redis
- **Mode**: Serverless
- **Region**: US East (N. Virginia)
- **Data Storage**: 1.5 GB average (staging), 7 GB average (production)
- **Min Storage**: 1 GB
- **Max Storage**: 10 GB

#### 5. Amazon S3
- **Service**: Amazon S3
- **Region**: US East (N. Virginia)
- **Storage**: 1 GB (staging), 10 GB (production)
- **Storage Class**: Standard
- **PUT Requests**: 100/month (staging), 500/month (production)
- **GET Requests**: 50,000/month (staging), 500,000/month (production)

#### 6. Amazon S3 (DR Region)
- **Service**: Amazon S3
- **Region**: US West (Oregon)
- **Storage**: 1 GB (staging), 10 GB (production)
- **Storage Class**: Standard-IA

#### 7. Amazon CloudFront
- **Service**: Amazon CloudFront
- **Data Transfer Out**: 10 GB/month (staging), 100 GB/month (production)
- **HTTPS Requests**: 50,000/month (staging), 500,000/month (production)
- **Price Class**: Use all edge locations

#### 8. Amazon VPC (NAT Gateway)
- **Service**: Amazon VPC
- **NAT Gateway**: 2 gateways
- **Region**: US East (N. Virginia)
- **Hours**: 730/month per gateway
- **Data Processed**: 10 GB/month (staging), 100 GB/month (production)

#### 9. Data Transfer
- **Service**: Data Transfer
- **Outbound to Internet**: 10 GB/month (staging), 100 GB/month (production)
- **Cross-Region**: 10 GB/month (staging), 100 GB/month (production)

#### 10. AWS WAF
- **Service**: AWS WAF
- **Web ACL**: 1
- **Rule Evaluations**: 300,000/month (staging), 3,000,000/month (production)
- **Region**: Global (CloudFront)

#### 11. AWS Secrets Manager
- **Service**: AWS Secrets Manager
- **Region**: US East (N. Virginia)
- **Secrets**: 1

#### 12. Amazon CloudWatch Logs
- **Service**: Amazon CloudWatch Logs
- **Region**: US East (N. Virginia)
- **Data Ingestion**: 5 GB/month (staging), 50 GB/month (production)
- **Storage**: 5 GB (staging), 50 GB (production)
- **Retention**: 30 days

#### 13. Amazon CloudWatch
- **Service**: Amazon CloudWatch
- **Region**: US East (N. Virginia)
- **Custom Metrics**: 10
- **Metric Alarms**: 8

#### 14. AWS CodePipeline
- **Service**: AWS CodePipeline
- **Region**: US East (N. Virginia)
- **Active Pipelines**: 3
- **Pipeline Executions**: 30/month

#### 15. AWS CodeBuild
- **Service**: AWS CodeBuild
- **Region**: US East (N. Virginia)
- **Compute Type**: Linux (3 GB memory, 2 vCPUs)
- **Build Minutes**: 60/month (staging), 120/month (production)

#### 16. Amazon ECR
- **Service**: Amazon ECR
- **Region**: US East (N. Virginia)
- **Storage**: 1 GB

#### 17. AWS Backup
- **Service**: AWS Backup
- **Region**: US East (N. Virginia)
- **Backup Storage**: 10 GB (staging), 100 GB (production)
- **Backup Operations**: 750/month
- **Cross-Region Copy**: Yes (us-west-2)
- **DR Region Storage**: 10 GB (staging), 100 GB (production)

#### 18. Amazon Route53
- **Service**: Amazon Route53
- **Hosted Zones**: 1
- **Health Checks**: 1
- **Queries**: 10,000/month

### Save and Share Estimate

1. **Review Total**: Verify the estimate matches the breakdown above
2. **Save Estimate**: Click "Save estimate"
3. **Share Link**: Copy the shareable link for documentation

---

## Cost Optimization Strategies

### 1. Right-Sizing

- **Aurora**: Monitor ACU usage and adjust min/max based on actual needs
  - Current: 0.5-4 ACU
  - Optimization: If average is consistently < 1 ACU, consider lowering max
- **Lambda**: Optimize memory allocation (more memory = faster execution = lower cost)
  - Current: 1024 MB
  - Optimization: Test with 512 MB or 2048 MB to find optimal cost/performance
- **ElastiCache**: Monitor cache hit ratio and adjust size
  - Current: 1-10 GB
  - Optimization: If usage is consistently < 2 GB, consider lowering max

### 2. Reserved Capacity

- **Not Applicable**: Serverless services don't support reserved capacity
- **Alternative**: Use provisioned concurrency for Lambda only if needed (adds cost)

### 3. Lifecycle Policies

- **S3**: Implement lifecycle policies for old data (move to Glacier after 90 days)
- **CloudWatch Logs**: Set retention policies (current: 30 days, consider 7 days for staging)
- **AWS Backup**: Review retention periods (current: 7 days hourly, 90 days daily)

### 4. Caching

- **CloudFront**: Maximize cache hit ratio (current: 80% staging, 85% production)
- **ElastiCache**: Optimize cache TTLs and hit ratio
- **API Gateway**: Consider response caching for static API responses

### 5. Data Transfer Optimization

- **CloudFront**: Use for all static content (already implemented)
- **VPC Endpoints**: Consider for AWS services (may reduce NAT Gateway costs)
  - S3 VPC Endpoint: $0.01/GB (vs NAT Gateway $0.045/GB)
  - DynamoDB VPC Endpoint: Free (if using DynamoDB)

### 6. Monitoring and Alerts

- **AWS Budgets**: Set up budget alerts
  - Warning: 80% of budget
  - Critical: 100% of budget
  - Forecasted: 120% of budget
- **Cost Explorer**: Regular cost reviews (weekly for staging, daily for production)
- **Tagging**: Use tags for cost allocation (already implemented)

### 7. DR Optimization

- **Backup Retention**: Review if 90-day daily backups are needed
- **Cross-Region Replication**: Consider reducing frequency or using cheaper storage classes
- **S3 Replication**: Standard-IA is already cost-optimized for DR

---

## Budget Recommendations

### Monthly Budget Allocation

**Staging Environment**: $206/month
- **Buffer**: 20% = $41/month
- **Total Budget**: $247/month

**Production Environment**: $997/month
- **Buffer**: 30% = $299/month
- **Total Budget**: $1,296/month

### Cost Alerts

**Recommended AWS Budgets**:

1. **Warning Alert**: 80% of budget
   - Staging: $165/month
   - Production: $798/month

2. **Critical Alert**: 100% of budget
   - Staging: $206/month
   - Production: $997/month

3. **Forecasted Alert**: 120% of budget
   - Staging: $247/month
   - Production: $1,196/month

**Setup via AWS Console**:
1. Go to AWS Budgets
2. Create budget → Cost budget
3. Set amount: $247 (staging) or $1,296 (production)
4. Configure alerts as above
5. Add email notifications

### Cost Optimization Review Schedule

- **Weekly**: Review CloudWatch cost metrics
- **Monthly**: Full cost analysis and optimization review
- **Quarterly**: Architecture review for cost optimization opportunities

---

## Notes

- **Pricing is approximate** and may vary based on actual usage
- **Free tier benefits** are included where applicable (Lambda, CloudFront, CloudWatch Logs)
- **Regional pricing** may differ (us-east-1 pricing used as baseline)
- **Data transfer costs** can vary significantly based on usage patterns
- **Backup costs** increase with retention period and frequency
- **ElastiCache Serverless** is the largest cost driver - monitor usage closely
- **NAT Gateway** is fixed cost - consider VPC endpoints for optimization

---

## References

- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS Pricing Documentation](https://aws.amazon.com/pricing/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Cost Optimization Best Practices](https://aws.amazon.com/pricing/cost-optimization/)
- [Aurora Serverless v2 Pricing](https://aws.amazon.com/rds/aurora/pricing/)
- [ElastiCache Serverless Pricing](https://aws.amazon.com/elasticache/pricing/)

---

**Last Updated**: November 2024  
**Next Review**: December 2024
