# Apprentice Final Project - Habit Tracker Application

## Overview

This project implements a multi-tier web application (Habit Tracker) that runs both locally using Docker Compose and in AWS using a serverless architecture. The application consists of a React frontend, Django REST API backend, PostgreSQL database, and Redis cache.

**Architecture Choice**: Option B - Serverless Architecture

**Key Technologies:**
- **Frontend**: React (Vite)
- **Backend**: Django (Python) running on AWS Lambda
- **Database**: Aurora Serverless v2 (PostgreSQL)
- **Cache**: ElastiCache Serverless (Redis)
- **Infrastructure**: Terraform (Infrastructure as Code)
- **CI/CD**: AWS CodePipeline with CodeBuild

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [AWS Deployment](#aws-deployment)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Health Checks](#health-checks)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **Terraform** (version 1.0+)
- **AWS CLI** (version 2.0+)
- **Node.js** (version 18+) - for local frontend development
- **Python** (version 3.11+) - for local backend development
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

## Local Development

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd PolymathFinalTask
   ```

2. **Set up environment variables**
   ```bash
   # Copy example environment file
   cp packages/api/local_settings.example.py packages/api/local_settings.py
   
   # Edit local_settings.py with your local database credentials
   # Or use the default SQLite configuration (for development only)
   ```

3. **Start the application with Docker Compose**
   ```bash
   cd packages
   docker-compose up --build
   ```

4. **Access the application**
   - Frontend: http://localhost
   - Backend API: http://localhost:8000
   - Health Check: http://localhost:8000/health/

5. **View logs**
   ```bash
   docker-compose logs -f
   # Or for specific service:
   docker-compose logs -f api
   docker-compose logs -f web
   docker-compose logs -f db
   docker-compose logs -f cache
   ```

### Local Development Details

#### Docker Compose Services

The `packages/docker-compose.yml` defines four containers:

1. **web** - React frontend (Vite dev server)
   - Port: 3000
   - Hot reload enabled
   - Environment: Development

2. **api** - Django backend API
   - Port: 8000
   - Database: PostgreSQL (db service)
   - Cache: Redis (cache service)
   - Auto-reload on code changes

3. **db** - PostgreSQL database
   - Port: 5432 (internal only)
   - Data persisted in Docker volume
   - Default database: `habit_tracker`

4. **cache** - Redis cache
   - Port: 6379 (internal only)
   - No persistence (ephemeral for development)

#### Environment Variables

All configuration is externalized via environment variables:

**Backend (.env or local_settings.py):**
- `DB_HOST` - Database hostname
- `DB_NAME` - Database name
- `DB_USER` - Database username
- `DB_PASSWORD` - Database password
- `DB_PORT` - Database port (default: 5432)
- `REDIS_HOST` - Redis hostname
- `REDIS_PORT` - Redis port (default: 6379)
- `SECRET_KEY` - Django secret key
- `DEBUG` - Debug mode (true/false)
- `ALLOWED_HOSTS` - Comma-separated list of allowed hosts

**Frontend:**
- `VITE_API_URL` - Backend API URL (default: http://localhost:8000)

### Running Tests Locally

```bash
# Backend tests
cd packages/api
python manage.py test

# Frontend tests (if configured)
cd packages/web
npm test
```

### Database Migrations

```bash
# Run migrations
cd packages/api
python manage.py migrate

# Create new migrations
python manage.py makemigrations
```

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
   - Uses the `lambda_image_uri` from `terraform.tfvars` (defaults to the manually seeded `apprentice-final-dummy:manual` image for initial deployment)
   - Stores Lambda configuration in SSM parameters for Backend pipeline
   - The backend pipeline later updates Lambda with the real image from the Terraform-managed ECR repository

2. **Backend Pipeline** (runs after Terraform, with approval stage):
   - **Source** → Pulls code from GitHub
   - **Source-Approval** → Manual approval (ensures Terraform pipeline completed first)
   - **Build** → Builds Docker image, pushes to ECR
   - **Deploy-Staging** → **Creates Lambda function if it doesn't exist**, or updates it with new image
   - **Test** → Runs health checks
   - **Approval** → Manual approval for production
   - **Deploy-Production** → Updates Lambda (production)

3. **Frontend Pipeline**:
   - Builds React application
   - Deploys to S3 and invalidates CloudFront

**First Deployment** (Automatic):
1. Terraform pipeline → Creates infrastructure including Lambda (using dummy image `apprentice-final-dummy:manual`)
2. Backend pipeline → Builds real image, pushes to ECR, updates Lambda with the real image
3. Frontend pipeline → Deploys frontend

**Subsequent Deployments** (Automatic):
- Terraform pipeline → Updates infrastructure (Lambda already exists)
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

The application is deployed automatically via AWS CodePipeline when code is pushed to the repository.

#### Pipeline Flow

1. **Source** - Pulls code from GitHub
2. **Source-Approval** - Manual approval to proceed
3. **Build** - Builds Docker images and frontend artifacts
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
│   ├── ARCHITECTURE_ASCII.md      # ASCII diagram of multi-region architecture
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
    ├── api/                       # Django backend
    │   ├── Habit_Tracker/        # Django project
    │   ├── habit/                 # Habit tracking app
    │   ├── Users/                 # User management app
    │   ├── Dockerfile             # Production container image
    │   ├── lambda_handler.py     # Lambda entry point
    │   ├── buildspec-backend.yml # Backend buildspec
    │   └── requirements.txt      # Python dependencies
    │
    ├── web/                       # React frontend
    │   ├── src/                   # React source code
    │   ├── public/               # Static assets
    │   ├── Dockerfile            # Production container image
    │   ├── buildspec-frontend.yml # Frontend buildspec
    │   └── package.json          # Node.js dependencies
    │
    └── docker-compose.yml         # Local development setup
```

---

## Configuration

### Environment Variables

All configuration is externalized - no hard-coded values.

#### AWS Lambda Environment Variables

Set via Terraform in `ops/iac/modules/compute/main.tf`:
- `DJANGO_SETTINGS_MODULE` - Django settings module
- `DEBUG` - Debug mode
- `REDIS_USE_TLS` - Redis TLS requirement
- `SESSION_COOKIE_SECURE` - Secure cookies
- `CSRF_COOKIE_SECURE` - Secure CSRF cookies
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
- `/apprentice-final/staging/django/secret_key` - Django secret key
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

### Application Health Endpoint

**URL**: `https://<api-gateway-url>/health/`

**Response**:
```json
{
  "status": "healthy",
  "services": {
    "database": {
      "status": "healthy",
      "message": "Database connection successful"
    },
    "cache": {
      "status": "healthy",
      "message": "Redis cache connection successful"
    }
  }
}
```

**Status Codes:**
- `200` - All services healthy
- `503` - One or more services unhealthy

### Authentication Check Endpoint

**URL**: `https://<api-gateway-url>/api/auth/check/`

**Response**:
```json
{
  "authenticated": true,
  "user_id": 1,
  "username": "testuser"
}
```

---

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture diagrams and component explanations
- **[ARCHITECTURE_ASCII.md](ARCHITECTURE_ASCII.md)** - ASCII diagram of the multi-region serverless architecture
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