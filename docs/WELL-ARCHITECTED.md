# AWS Well-Architected Framework Mapping

## Table of Contents

- [Overview](#overview)
- [Operational Excellence](#operational-excellence)
- [Security](#security)
- [Reliability](#reliability)
- [Performance Efficiency](#performance-efficiency)
- [Cost Optimization](#cost-optimization)
- [Sustainability](#sustainability)

---

## Overview

This document maps the Habit Tracker application infrastructure to the AWS Well-Architected Framework's six pillars. Each pillar is evaluated with evidence and implementation details.

---

## Operational Excellence

### Pillar Summary

Operational Excellence focuses on running and monitoring systems to deliver business value and continuously improve supporting processes and procedures.

### Design Principles

 **Perform operations as code**  
 **Make frequent, small, reversible changes**  
 **Refine operations procedures frequently**  
 **Anticipate failure**  
 **Learn from all operational events**

### Implementation Evidence

#### 1. Infrastructure as Code (IaC)

**Evidence**:
- All infrastructure defined in Terraform
- Modular design (network, compute, data, edge, observability, iam modules)
- Version controlled in Git
- Remote state in S3 with DynamoDB locking

**Files**:
- `ops/iac/main.tf` - Root module
- `ops/iac/modules/*/` - Modular components
- `ops/iac/providers.tf` - Backend configuration

#### 2. CI/CD Automation

**Evidence**:
- AWS CodePipeline for automated deployments
- Separate pipelines for Terraform, Backend, and Frontend
- Automated testing and health checks
- Approval stages for production deployments

**Files**:
- `ops/cicd/pipelines.tf` - Pipeline definitions
- `packages/api/buildspec-backend.yml` - Backend buildspec
- `packages/web/buildspec-frontend.yml` - Frontend buildspec

#### 3. Monitoring and Logging

**Evidence**:
- CloudWatch Logs for all services
- CloudWatch Dashboards for visualization
- CloudWatch Alarms for proactive alerting
- SNS notifications for critical events

**Files**:
- `ops/iac/modules/observability/main.tf` - Monitoring configuration

**Metrics Monitored**:
- API Gateway: Request counts, latency, error rates
- Lambda: Invocations, duration, errors, throttles
- Aurora: Connections, CPU, storage
- ElastiCache: Connections, memory, CPU

#### 4. Runbooks and Documentation

**Evidence**:
- `docs/RUNBOOK.md` - Operational procedures
- `docs/RUNBOOK_DR.md` - Disaster recovery procedures
- `docs/README.md` - Setup and deployment guide
- `docs/ARCHITECTURE.md` - Architecture documentation

#### 5. Change Management

**Evidence**:
- Git-based version control
- Terraform plan before apply
- Pipeline approval stages
- Rollback procedures documented


---

## Security

### Pillar Summary

Security focuses on protecting information, systems, and assets while delivering business value through risk assessments and mitigation strategies.

### Design Principles

 **Implement a strong identity foundation**  
 **Apply security at all layers**  
 **Enable traceability**  
 **Automate security best practices**  
 **Protect data in transit and at rest**  
 **Keep people away from data**  
 **Prepare for security events**

### Implementation Evidence

#### 1. Identity and Access Management (IAM)

**Evidence**:
- Least-privilege IAM roles for all services
- Dedicated operator role for project management
- No hardcoded credentials
- Secrets Manager for sensitive data
- SSM Parameter Store for configuration

**Files**:
- `ops/iac/modules/iam/main.tf` - IAM roles and policies
- `ops/iac/modules/compute/main.tf` - Lambda execution role

**IAM Roles**:
- `apprentice-final-staging-lambda-role` - Lambda execution (VPC, Secrets, SSM)
- `apprentice-final-staging-apigw-cloudwatch-role` - API Gateway logging
- `apprentice-final-staging-operator-role` - Project operator (least privilege)

#### 2. Network Security

**Evidence**:
- VPC with private subnets for data layer
- Security groups with least-privilege rules
- No public IPs for Lambda, Aurora, Redis
- NAT Gateway for controlled outbound access
- WAF for CloudFront protection

**Files**:
- `ops/iac/modules/network/main.tf` - VPC and security groups
- `ops/iac/modules/edge/main.tf` - WAF configuration

**Security Groups**:
- Lambda: Egress only (all outbound)
- Aurora: Ingress from Lambda only (port 5432)
- ElastiCache: Ingress from Lambda only (port 6379)

#### 3. Data Protection

**Evidence**:
- Encryption at rest: Aurora (KMS), S3 (SSE), Secrets Manager (KMS)
- Encryption in transit: HTTPS (TLS 1.2+), Redis TLS, Database TLS
- Secrets Manager for database credentials
- No secrets in code or environment variables

**Files**:
- `ops/iac/modules/data/main.tf` - Aurora encryption
- `ops/iac/modules/compute/main.tf` - Secrets Manager integration

#### 4. Application Security

**Evidence**:
- WAF rules for common web exploits
- CORS configuration for specific origins
- CSRF protection with trusted origins
- Input validation in Django
- Secure cookies (HttpOnly, Secure, SameSite)

**Files**:
- `packages/api/Habit_Tracker/settings.py` - Security settings
- `ops/iac/modules/edge/main.tf` - WAF configuration

#### 5. Compliance and Auditing

**Evidence**:
- CloudTrail enabled (AWS managed)
- CloudWatch Logs for all services
- IAM access logging
- Tagged resources for compliance tracking

**Tags Applied**:
- `Environment` - staging/production
- `Project` - apprentice-final
- `Owner` - Bardh Serreqi
- `ManagedBy` - Terraform

#### 6. Incident Response

**Evidence**:
- CloudWatch Alarms for security events
- SNS notifications for alerts
- Runbook with recovery procedures
- Backup and restore procedures

**Files**:
- `docs/RUNBOOK.md` - Incident response procedures

---

## Reliability

### Pillar Summary

Reliability focuses on the ability of a system to recover from infrastructure or service disruptions, dynamically acquire computing resources to meet demand, and mitigate disruptions such as misconfigurations or transient network issues.

### Design Principles

 **Test recovery procedures**  
 **Automatically recover from failure**  
 **Scale horizontally to increase aggregate system availability**  
 **Stop guessing capacity**  
 **Manage change in automation**

### Implementation Evidence

#### 1. High Availability (HA)

**Evidence**:
- Multi-AZ deployment for Aurora (automatic)
- Multi-AZ deployment for ElastiCache Serverless (automatic)
- CloudFront global edge network
- Lambda automatic scaling across AZs

**Files**:
- `ops/iac/modules/data/main.tf` - Aurora and ElastiCache configuration

#### 2. Disaster Recovery (DR)

**Evidence**:
- Pilot Light DR strategy (RTO: 4h, RPO: 1h)
- Automated hourly backups (7-day retention)
- Daily backups (90-day retention)
- Cross-region backup replication to us-west-2

**Files**:
- `ops/iac/modules/data/backup.tf` - Backup configuration
- `docs/DR_STRATEGY.md` - DR strategy documentation
- `docs/RUNBOOK_DR.md` - DR procedures

#### 3. Automatic Scaling

**Evidence**:
- Lambda: Automatic scaling based on requests
- Aurora Serverless v2: Auto-scales ACU (0.5-4 ACU)
- ElastiCache Serverless: Auto-scales storage
- CloudFront: Global edge network handles traffic spikes

**Files**:
- `ops/iac/modules/compute/main.tf` - Lambda configuration
- `ops/iac/modules/data/main.tf` - Aurora scaling configuration

#### 4. Fault Tolerance

**Evidence**:
- Health checks for all services
- Automatic retry logic in Lambda
- Database connection pooling
- Redis caching reduces database load

**Files**:
- `packages/api/habit/health.py` - Health check endpoint
- `packages/api/Habit_Tracker/settings.py` - Database and cache configuration

#### 5. Change Management

**Evidence**:
- Terraform for infrastructure changes
- CI/CD pipelines for application changes
- Approval stages for production
- Rollback procedures documented

**Files**:
- `ops/cicd/pipelines.tf` - Pipeline approval stages
- `docs/RUNBOOK.md` - Rollback procedures

#### 6. Monitoring and Alerting

**Evidence**:
- CloudWatch Alarms for critical metrics
- SNS notifications for alerts
- CloudWatch Dashboards for visualization
- Health check endpoint for automated testing

**Files**:
- `ops/iac/modules/observability/main.tf` - Alarms and dashboards

**Alarms Configured**:
- API Gateway 5xx errors (>5% for 5 minutes)
- API Gateway high latency (>1s for 5 minutes)
- Lambda errors (>10 in 5 minutes)
- Lambda throttles (>5 in 5 minutes)
- Aurora high connections (>80% of max)
- Aurora high CPU (>80% for 5 minutes)
- Redis high CPU (>80% for 5 minutes)
- Redis high memory (>90% for 5 minutes)

---

## Performance Efficiency

### Pillar Summary

Performance Efficiency focuses on using computing resources efficiently to meet system requirements and maintaining that efficiency as demand changes and technologies evolve.

### Design Principles

 **Democratize advanced technologies**  
 **Go global in minutes**  
 **Use serverless architectures**  
 **Experiment more often**  
 **Consider mechanical sympathy**

### Implementation Evidence

#### 1. Serverless Architecture

**Evidence**:
- Lambda for compute (pay per request)
- Aurora Serverless v2 (auto-scales ACU)
- ElastiCache Serverless (auto-scales storage)
- S3 for static hosting

#### 2. Caching Strategy

**Evidence**:
- CloudFront CDN for static assets
- ElastiCache Redis for application caching
- Django cache framework integration
- Session storage in Redis

**Files**:
- `packages/api/Habit_Tracker/settings.py` - Cache configuration
- `ops/iac/modules/edge/main.tf` - CloudFront configuration

#### 3. Database Optimization

**Evidence**:
- Aurora Serverless v2 for automatic scaling
- Connection pooling in Django
- Read replicas available (optional)
- Indexed database tables

**Files**:
- `ops/iac/modules/data/main.tf` - Aurora configuration

#### 4. Content Delivery

**Evidence**:
- CloudFront global edge network
- S3 static hosting for frontend
- CloudFront Functions for SPA routing
- Compression enabled (gzip)

**Files**:
- `ops/iac/modules/edge/main.tf` - CloudFront configuration

#### 5. Monitoring Performance

**Evidence**:
- CloudWatch metrics for latency
- CloudWatch Dashboards for performance visualization
- API Gateway request/response logging
- Lambda duration metrics

**Files**:
- `ops/iac/modules/observability/main.tf` - Performance metrics

**Metrics Tracked**:
- API Gateway: Latency (p50, p95, p99)
- Lambda: Duration (average, max)
- Aurora: Query performance, connections
- ElastiCache: Cache hit ratio

---

## Cost Optimization

### Pillar Summary

Cost Optimization focuses on avoiding unnecessary costs and selecting the most appropriate resource types and sizes based on workload requirements.

### Design Principles

 **Adopt a consumption model**  
 **Measure overall efficiency**  
 **Stop spending money on undifferentiated heavy lifting**  
 **Analyze and attribute expenditure**  
 **Use managed services to reduce cost of ownership**

### Implementation Evidence

#### 1. Serverless Services (Consumption Model)

**Evidence**:
- Lambda: Pay per request (no idle costs)
- Aurora Serverless v2: Pay for ACU usage (scales to 0.5 ACU)
- ElastiCache Serverless: Pay for data stored
- API Gateway: Pay per API call

#### 2. Cost Monitoring

**Evidence**:
- AWS Cost Explorer (AWS managed)
- Tagged resources for cost allocation
- CloudWatch metrics for resource usage

**Tags for Cost Allocation**:
- `Environment` - staging/production
- `Project` - apprentice-final
- `Component` - compute/data/edge/network

#### 3. Managed Services

**Evidence**:
- Aurora (managed database)
- ElastiCache (managed cache)
- CloudFront (managed CDN)
- API Gateway (managed API service)
- Lambda (managed compute)

#### 4. Right-Sizing

**Evidence**:
- Aurora Serverless v2: Auto-scales (0.5-4 ACU)
- Lambda: Memory auto-configured
- ElastiCache Serverless: Auto-scales storage
- No over-provisioned resources

**Files**:
- `ops/iac/modules/data/main.tf` - Aurora scaling configuration

#### 5. Cost Optimization Strategies

**Evidence**:
- S3 static hosting (cost-effective)
- CloudFront free tier (1TB transfer)
- Reserved capacity not applicable (serverless)
- Spot instances not applicable (serverless)

#### 6. Cost Documentation

**Evidence**:
- `docs/COST.md` - Cost analysis document
- AWS Pricing Calculator estimate
- Monthly cost breakdown

---

## Sustainability

### Pillar Summary

Sustainability focuses on minimizing the environmental impact of cloud workloads by maximizing resource utilization and minimizing waste.

### Design Principles

 **Understand your impact**  
 **Establish sustainability goals**  
 **Maximize utilization**  
 **Anticipate and adopt new, more efficient hardware and software offerings**  
 **Use managed services**  
 **Reduce the downstream impact of your cloud workloads**

### Implementation Evidence

#### 1. Resource Efficiency

**Evidence**:
- Serverless services (no idle resources)
- Auto-scaling (resources scale to demand)
- Multi-AZ deployment (efficient resource utilization)
- CloudFront edge caching (reduces origin requests)

#### 2. Managed Services

**Evidence**:
- Aurora (AWS manages infrastructure)
- ElastiCache (AWS manages infrastructure)
- Lambda (AWS manages infrastructure)
- CloudFront (AWS manages edge infrastructure)

#### 3. Data Transfer Optimization

**Evidence**:
- CloudFront CDN (reduces origin data transfer)
- S3 static hosting (efficient for static content)
- Compression enabled (gzip)
- API Gateway (efficient request routing)

#### 4. Geographic Optimization

**Evidence**:
- Primary region: us-east-1 (efficient for US users)
- CloudFront global edge (serves from nearest location)
- DR region: us-west-2 (minimal resources)

---


### Overall Assessment

The architecture demonstrates strong alignment with AWS Well-Architected Framework principles. Key strengths include:

- **Infrastructure as Code**: All infrastructure versioned and automated
- **Security**: Least-privilege IAM, encryption, WAF protection
- **Reliability**: Multi-AZ, automated backups, health checks, disaster recovery
- **Performance**: Serverless auto-scaling, CDN, caching
- **Cost**: Consumption-based pricing, no idle costs
- **Sustainability**: Efficient resource utilization, managed services
