# Apprentice Final Project - AWS Serverless Infrastructure

## Overview

This project implements a complete AWS serverless infrastructure using Infrastructure as Code (Terraform). The infrastructure supports a multi-tier serverless architecture with automated CI/CD pipelines.

**Architecture Choice**: Option B - Serverless Architecture

**Key AWS Services:**
- **Compute**: AWS Lambda (container images)
- **Database**: Aurora Serverless v2 (PostgreSQL)
- **Cache**: ElastiCache Serverless (Redis)
- **Storage**: S3 (static content hosting)
- **CDN**: CloudFront with WAF
- **API**: API Gateway (HTTP API)
- **Infrastructure as Code**: Terraform (modular design)
- **CI/CD**: AWS CodePipeline with CodeBuild

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [AWS Deployment](#aws-deployment)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Health Checks](#health-checks)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Terraform** (version 1.0+)
- **AWS CLI** (version 2.0+)
- **Git**

### AWS Account Requirements

- AWS Account with appropriate permissions
- AWS CLI configured with credentials
- Terraform state S3 bucket and DynamoDB table (created manually or via bootstrap)
- Route53 hosted zone for custom domain (optional)

### Required AWS Permissions

The IAM user/role needs permissions for:
- VPC, EC2, Lambda, API Gateway, RDS, ElastiCache, S3, CloudFront, WAF, Route53, ACM, CloudWatch, SNS, Secrets Manager, SSM, IAM, CodePipeline, CodeBuild, ECR, Backup

See `ops/iac/modules/iam/` for the least-privilege operator role configuration.

---

## AWS Deployment

### Infrastructure Deployment (Terraform)

#### Prerequisites

1. **Configure Terraform Backend**
   - Ensure S3 bucket exists: `bardhi-apprentice-final-state`
   - Ensure DynamoDB table exists: `apprentice-final-terraform-state-lock`
   - Backend configuration is in `ops/iac/providers.tf`

2. **Set up Terraform Variables**
   ```bash
   cd ops/iac
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

#### Deploy Infrastructure

**Fully Automated via CI/CD Pipelines**

The deployment is fully automated through AWS CodePipeline. No manual steps required:

**Deployment Flow**:

1. **Terraform Pipeline**:
   - Creates infrastructure (VPC, ECR, S3, CloudFront, Aurora, Redis, API Gateway, Lambda, etc.)
   - Uses the `lambda_image_uri` from `terraform.tfvars`
   - Stores Lambda configuration in SSM parameters for application pipelines
   - Application pipelines later update Lambda with images from the Terraform-managed ECR repository

2. **Backend Pipeline** (runs after Terraform, with approval stage):
   - **Source** → Pulls code from GitHub
   - **Source-Approval** → Manual approval (ensures Terraform pipeline completed first)
   - **Build** → Builds Docker image, pushes to ECR
   - **Deploy-Staging** → Creates Lambda function if it doesn't exist, or updates it with new image
   - **Test** → Runs health checks
   - **Approval** → Manual approval for production
   - **Deploy-Production** → Updates Lambda (production)

3. **Frontend Pipeline**:
   - Builds frontend application
   - Deploys to S3 and invalidates CloudFront

**First Deployment** (Automatic):
1. Terraform pipeline → Creates infrastructure including Lambda
2. Backend pipeline → Builds container image, pushes to ECR, updates Lambda
3. Frontend pipeline → Deploys frontend to S3

**Subsequent Deployments** (Automatic):
- Terraform pipeline → Updates infrastructure
- Backend pipeline → Builds new image, updates Lambda
- Frontend pipeline → Deploys new build

**Manual Deployment** (Optional):

```bash
cd ops/iac

# Review changes
terraform plan

# Apply infrastructure
terraform apply
```

**Deployment Time**: ~15-20 minutes for initial deployment

#### Deploy CI/CD Pipelines

```bash
cd ops/cicd

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### Application Deployment (CI/CD)

Application code is deployed automatically via AWS CodePipeline when code is pushed to the repository.

#### Pipeline Flow

1. **Source** - Pulls code from GitHub
2. **Source-Approval** - Manual approval to proceed
3. **Build** - Builds container images and frontend artifacts
4. **Deploy-Staging** - Deploys to staging environment
5. **Test** - Runs health checks
6. **Approval** - Manual approval for production
7. **Deploy-Production** - Deploys to production
8. **Notify** - Sends deployment notifications

#### Manual Pipeline Trigger

If needed, you can manually trigger pipelines:
- AWS Console → CodePipeline → Select pipeline → "Release change"

### Post-Deployment Verification

1. **Check Health Endpoint**
   ```bash
   curl https://<your-api-gateway-url>/health/
   ```

2. **Verify Frontend**
   - Visit: `https://<your-cloudfront-domain>` or `https://<your-custom-domain>`

3. **Check CloudWatch Logs**
   - Lambda logs: `/aws/lambda/apprentice-final-staging-api`
   - API Gateway logs: `/aws/apigateway/apprentice-final-staging-http-api`

4. **Verify Monitoring**
   - CloudWatch Dashboard: `apprentice-final-staging-overview`
   - Check SNS topic subscriptions (confirm email)

---

## Project Structure

```
PolymathFinalTask/
├── docs/                          # Documentation
│   ├── README.md                  # This file
│   ├── ARCHITECTURE.md            # Architecture documentation
│   ├── RUNBOOK.md                 # Operational runbook
│   ├── WELL-ARCHITECTED.md        # AWS Well-Architected Framework mapping
│   └── COST.md                    # Cost analysis
│
├── ops/                           # Infrastructure and CI/CD
│   ├── iac/                       # Infrastructure as Code (Terraform)
│   │   ├── main.tf                # Root module
│   │   ├── variables.tf            # Root variables
│   │   ├── providers.tf           # Terraform providers and backend
│   │   ├── terraform.tfvars       # Variable values (gitignored)
│   │   └── modules/               # Terraform modules
│   │       ├── network/           # VPC, subnets, NAT, IGW
│   │       ├── compute/           # Lambda, API Gateway, ECR
│   │       ├── data/              # Aurora, ElastiCache, S3, Secrets, SSM
│   │       ├── edge/              # CloudFront, WAF, Route53, ACM
│   │       ├── observability/     # CloudWatch dashboards, alarms, logs
│   │       └── iam/               # IAM roles and policies
│   │
│   └── cicd/                      # CI/CD Pipeline (Terraform)
│       ├── main.tf                # Pipeline resources
│       ├── pipelines.tf           # CodePipeline definitions
│       ├── iam.tf                 # Pipeline IAM roles
│       ├── notifications.tf       # SNS notifications
│       └── terraform.tfvars       # CI/CD variables
│
└── packages/                      # Application code
    ├── api/                       # Backend application
    │   ├── Dockerfile             # Production container image
    │   ├── buildspec-backend.yml  # Backend buildspec
    │   └── requirements.txt       # Dependencies
    │
    └── web/                       # Frontend application
        ├── Dockerfile             # Production container image
        ├── buildspec-frontend.yml # Frontend buildspec
        └── package.json           # Dependencies
```

---

## Configuration

### Environment Variables

All configuration is externalized - no hard-coded values.

#### AWS Lambda Environment Variables

Set via Terraform in `ops/iac/modules/compute/main.tf`:
- Environment variables configured via `lambda_environment` variable in `terraform.tfvars`
- `AWS_SECRET_NAME` - Secrets Manager secret ARN
- `AWS_SSM_PREFIX` - SSM parameter prefix
- `AURORA_WRITER_ENDPOINT_PARAM` - Aurora endpoint SSM parameter
- `REDIS_ENDPOINT_PARAM` - Redis endpoint SSM parameter

#### Secrets and Parameters

**AWS Secrets Manager:**
- `/apprentice-final/staging/aurora/master` - Database credentials

**SSM Parameter Store:**
- `/apprentice-final/staging/aurora/writer_endpoint` - Aurora writer endpoint
- `/apprentice-final/staging/aurora/reader_endpoint` - Aurora reader endpoint
- `/apprentice-final/staging/redis/endpoint` - Redis endpoint
- `/apprentice-final/staging/django/secret_key` - Application secret key
- `/apprentice-final/staging/django/debug` - Debug setting
- `/apprentice-final/staging/django/allowed_hosts` - Allowed hosts
- `/apprentice-final/staging/django/csrf_trusted_origins` - CSRF trusted origins
- `/apprentice-final/staging/lambda/function_name` - Lambda function name
- `/apprentice-final/staging/lambda/role_arn` - Lambda IAM role ARN
- `/apprentice-final/staging/lambda/security_group_id` - Lambda security group ID
- `/apprentice-final/staging/lambda/subnet_ids` - Lambda subnet IDs (JSON array)
- `/apprentice-final/staging/lambda/config` - Lambda configuration (timeout, memory, env vars)
- `/apprentice-final/staging/ecr/repository_url` - ECR repository URL
- `/apprentice-final/staging/s3/frontend_bucket_name` - Frontend bucket name
- `/apprentice-final/staging/cloudfront/distribution_id` - CloudFront distribution ID
- `/apprentice-final/staging/cloudfront/domain_name` - CloudFront domain name
- `/apprentice-final/staging/api_gateway/url` - API Gateway URL

---

## Health Checks

### Infrastructure Health Endpoint

**URL**: `https://<api-gateway-url>/health/`

**Purpose**: Verify Lambda function connectivity to Aurora and ElastiCache

**Status Codes:**
- `200` - All services healthy
- `503` - One or more services unhealthy

**Verification**:
- Check Lambda CloudWatch logs for connection status
- Verify security groups allow traffic
- Confirm Secrets Manager and SSM parameters are accessible

---

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture diagrams and AWS component explanations
- **[RUNBOOK.md](RUNBOOK.md)** - Operational procedures and troubleshooting
- **[WELL-ARCHITECTED.md](WELL-ARCHITECTED.md)** - AWS Well-Architected Framework mapping
- **[COST.md](COST.md)** - Cost analysis and AWS Pricing Calculator breakdown

---

## Troubleshooting

### Common Issues

#### 1. Lambda Function Not Invoking

**Symptoms**: API Gateway returns 500/502 errors

**Solutions**:
- Check Lambda logs in CloudWatch: `/aws/lambda/apprentice-final-staging-api`
- Verify Lambda has VPC access (check security groups)
- Verify Lambda has permissions to Secrets Manager and SSM
- Check Lambda environment variables are set correctly

#### 2. Database Connection Errors

**Symptoms**: Health check shows database as unhealthy

**Solutions**:
- Verify Aurora cluster is available (check RDS console)
- Check Lambda security group allows outbound to Aurora (port 5432)
- Verify Aurora security group allows inbound from Lambda security group
- Check Secrets Manager secret exists and contains correct credentials
- Verify SSM parameter `/apprentice-final/staging/aurora/writer_endpoint` exists

#### 3. Redis Connection Errors

**Symptoms**: Health check shows cache as unhealthy

**Solutions**:
- Verify ElastiCache Serverless cache is available
- Check Lambda security group allows outbound to Redis (port 6379)
- Verify Redis security group allows inbound from Lambda security group
- Check `REDIS_USE_TLS=true` is set (required for Serverless)
- Verify SSM parameter `/apprentice-final/staging/redis/endpoint` exists

#### 4. Frontend Not Loading

**Symptoms**: CloudFront returns 403 or blank page

**Solutions**:
- Verify S3 bucket has files (check S3 console)
- Check CloudFront distribution is deployed
- Verify S3 bucket policy allows CloudFront OAC access
- Check CloudFront function is attached and published
- Verify Route53 record points to CloudFront (if using custom domain)

#### 5. CI/CD Pipeline Failures

**Symptoms**: Pipeline stages failing

**Solutions**:
- Check CodeBuild logs for specific errors
- Verify IAM roles have required permissions
- Check S3 bucket for pipeline artifacts exists
- Verify GitHub connection is active
- Check Terraform state bucket and lock table exist

### Getting Help

1. **Check CloudWatch Logs** - Most issues are logged
2. **Review Terraform State** - `terraform show` to see current state
3. **Check AWS Console** - Verify resources exist and are configured correctly
4. **Review Documentation** - See `docs/RUNBOOK.md` for detailed procedures

---

## Security Notes

- **Secrets**: All sensitive data stored in AWS Secrets Manager
- **IAM**: Least-privilege access via operator role
- **WAF**: Web Application Firewall protects CloudFront
- **HTTPS**: All traffic encrypted (ACM certificates)
- **VPC**: Lambda runs in private subnets with NAT gateway
- **Encryption**: All data encrypted at rest (Aurora, S3, Secrets Manager)

---

## Cost Optimization

- **Aurora Serverless v2**: Auto-scales based on demand
- **ElastiCache Serverless**: Pay only for data stored
- **Lambda**: Pay per request (no idle costs)
- **S3**: Static hosting is cost-effective
- **CloudFront**: Free tier includes 1TB data transfer

See [COST.md](COST.md) for detailed cost analysis.