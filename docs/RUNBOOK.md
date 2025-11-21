# Operational Runbook

## Table of Contents

- [Overview](#overview)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Procedures](#deployment-procedures)
- [Recovery Procedures](#recovery-procedures)
- [Testing Alerts](#testing-alerts)
---

## Overview

This runbook provides step-by-step operational procedures for managing the Habit Tracker application infrastructure and application deployments. It covers deployment, rollback, recovery, scaling, and alert testing procedures.

**Environment**: Staging (Production procedures are similar)

**Architecture**: Serverless (Lambda, Aurora Serverless v2, ElastiCache Serverless)

---

## Pre-Deployment Checklist

Before deploying any changes, verify:

- AWS CodePipeline connections (GitHub source) are healthy
-  notification subscriptions are confirmed
- CloudWatch dashboards are accessible
- Backup vaults exist in primary and DR regions
- Route53 hosted zone is configured in console (if using custom domain)
- `ops/cicd/terraform.tfvars` is up to date (see manual deployment below)

> **Note:** All infrastructure and application deployments are handled automatically by CI/CD. Manual `terraform` commands inside `ops/iac/` are no longer required.

---

## Deployment Procedures

### CI/CD Pipeline Deployment (Default)

All deployments—Terraform infrastructure, backend Lambda, and frontend SPA—run through their respective AWS CodePipelines.

1. **Trigger Pipelines**
   - Commit/push changes to `main` (or target branch) → Pipelines start automatically.
   - To re-run manually: AWS Console → CodePipeline → Select pipeline → “Release change”.

2. **Pipeline Flow**
   - **Terraform pipeline**: Plans/applies `ops/iac` automatically; no manual (local terminal) `terraform` commands needed.
   - **Backend pipeline**: Builds/pushes Lambda container to ECR, updates Lambda, runs health checks.
   - **Frontend pipeline**: Builds React app, syncs to S3, invalidates CloudFront.

3. **Monitor Pipelines**
   - Watch pipeline dashboards in AWS Console.
   - Review CodeBuild logs for failures.
   - Handle approval stages when prompted (Source-Approval, Deploy-Approval, etc.).

4. **Post-Deployment Verification**
   ```bash
   # Backend health
   curl https://<api-gateway-url>/health/

   # Frontend
   open https://<cloudfront-domain>/
   ```

### Manual CI/CD Module Deployment (ops/cicd)

The only Terraform that must be run manually is for provisioning the CI/CD stack itself (`ops/cicd`). Run these steps only when creating or updating the pipelines/IAM roles:

1. Configure variables
   ```bash
   cd ops/cicd
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with account-specific values (state bucket, GitHub repo, etc.)
   ```

2. Initialize/apply
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Once the CI/CD stack exists, **stop running Terraform manually**. Allow the pipelines to manage all subsequent infrastructure and application deployments.

---

## Testing Alerts

### Test CloudWatch Alarms

#### Test API Gateway 5xx Alarm

1. **Trigger 5xx Errors**
   ```bash
   # Cause errors by sending invalid requests
   # Or temporarily break Lambda function
   ```

2. **Verify Alarm**
   - Check CloudWatch → Alarms
   - Alarm should enter ALARM state
   - SNS notification should be sent

3. **Verify Email**
   - Check email inbox
   - Email should contain alarm details

#### Test Lambda Error Alarm

1. **Trigger Lambda Errors**
   ```bash
   # Temporarily break Lambda code
   # Or send invalid payload
   ```

2. **Verify Alarm**
   - Check CloudWatch → Alarms
   - Alarm should trigger


### Test SNS Notifications

1. **Send Test Message**
   ```bash
   aws sns publish \
     --topic-arn arn:aws:sns:us-east-1:967746377724:apprentice-final-staging-alerts \
     --message "Test alert from runbook" \
     --subject "Test Alert"
   ```

2. **Verify Email**
   - Check email inbox
   - Email should be received

### Alert Subscription Management

**Add Email Subscription**:
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:967746377724:apprentice-final-staging-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

**Confirm Subscription**:
- Check email inbox for confirmation link
- Click link to confirm

**Remove Subscription**:
```bash
aws sns unsubscribe \
  --subscription-arn <subscription-arn>
```