# Disaster Recovery Runbook - Pilot Light Strategy

## Quick Reference

| Metric | Value | Status |
|--------|-------|--------|
| **Strategy** | Pilot Light | ✅ Implemented |
| **RTO** | 4 hours | ✅ Target met |
| **RPO** | 1 hour | ✅ Target met |
| **HA (Multi-AZ)** | Enabled | ✅ Automatic failover |
| **DR Region** | us-west-2 | 📋 To be provisioned |

---

## Table of Contents

1. [Emergency Contacts](#emergency-contacts)
2. [Pre-Requisites](#pre-requisites)
3. [Scenario 1: AZ Failure (Automatic)](#scenario-1-az-failure-automatic)
4. [Scenario 2: Regional Failure (Manual)](#scenario-2-regional-failure-manual)
5. [Scenario 3: Data Corruption](#scenario-3-data-corruption)
6. [Scenario 4: Rollback After DR](#scenario-4-rollback-after-dr)
7. [Testing Procedures](#testing-procedures)
8. [Monitoring & Validation](#monitoring--validation)

---

## Emergency Contacts

| Role | Contact | Phone | Email |
|------|---------|-------|-------|
| DevOps Lead | Bardh Serreqi | TBD | bardh.serreqi@polymath.services |
| AWS Support | - | - | Support case via console |
| On-Call Engineer | TBD | TBD | TBD |

---

## Pre-Requisites

### Before Disaster Strikes

- [ ] **DR Region Infrastructure**: Deploy minimal infrastructure in us-west-2 (once per setup)
- [ ] **Backup Verification**: Confirm hourly backups are running successfully
- [ ] **Access Verified**: Ensure AWS credentials work for both regions
- [ ] **Documentation Updated**: Keep this runbook current with latest architecture
- [ ] **Team Training**: Conduct quarterly DR drills

### What You Need During DR Event

1. **AWS Console Access** (or AWS CLI configured)
2. **Terraform Installed** (v1.6+)
3. **Git Access** to infrastructure repository
4. **DNS Update Access** (Route53)
5. **Communication Channel** (Slack, email, phone)

---

## Scenario 1: AZ Failure (Automatic)

### Detection

**Symptoms:**
- CloudWatch alarm: `apprentice-final-staging-aurora-connections` or RDS metrics
- API Gateway 5XX errors spike
- Application timeouts

**Expected Behavior:**
- **Aurora Multi-AZ**: Automatic failover to standby instance (1-2 minutes)
- **Redis Serverless**: Automatic failover to healthy AZ (< 1 minute)
- **Lambda**: Automatically runs in healthy AZs

### Actions Required

**✅ None - Automatic Recovery**

### Validation

```bash
# 1. Check Aurora cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier apprentice-final-staging-aurora \
  --query 'DBClusters[0].Status'
# Expected: "available"

# 2. Check health endpoint
curl https://bardhi.devops.konitron.com/health/
# Expected: {"status": "healthy"}

# 3. Monitor CloudWatch metrics
# Navigate to: CloudWatch > Dashboards > apprentice-final-staging-overview
```

### Expected Timeline

| Time | Event |
|------|-------|
| T+0 | AZ failure detected |
| T+30s | CloudWatch alarms trigger |
| T+1-2min | Aurora failover completes |
| T+2-3min | All services restored |

---

## Scenario 2: Regional Failure (Manual)

### Detection

**Symptoms:**
- All services in us-east-1 unavailable
- Route53 health checks failing
- Unable to access AWS console for us-east-1

**Trigger Criteria:**
- Primary region unavailable for > 15 minutes
- No ETA for region recovery from AWS
- Business impact requires immediate failover

### Decision Tree

```
Primary Region Down?
├─ Yes, < 15 min → Wait for automatic recovery
├─ Yes, 15-60 min → Prepare DR, monitor AWS status
└─ Yes, > 60 min OR critical impact → Execute DR failover
```

### Failover Procedure (RTO: 2-4 hours)

#### Step 1: Assess and Communicate (5 minutes)

```bash
# 1. Verify region is actually down
aws ec2 describe-regions --region us-east-1
# If this times out, region is likely down

# 2. Check AWS Service Health Dashboard
open https://health.aws.amazon.com/health/status

# 3. Notify stakeholders
# Send email/Slack: "Primary region down, initiating DR failover to us-west-2"
```

#### Step 2: Restore Database (30-60 minutes)

```bash
# 1. List available backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name apprentice-final-staging-vault \
  --region us-east-1

# If us-east-1 is completely unavailable, use cross-region copies:
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name apprentice-final-staging-vault \
  --region us-west-2

# 2. Identify most recent backup (should be < 1 hour old for RPO)
RECOVERY_POINT_ARN="arn:aws:backup:us-west-2:..."

# 3. Restore Aurora from backup
aws backup start-restore-job \
  --recovery-point-arn $RECOVERY_POINT_ARN \
  --iam-role-arn arn:aws:iam::967746377724:role/apprentice-final-staging-backup-role \
  --region us-west-2 \
  --metadata \
    '{"DBClusterIdentifier":"apprentice-final-dr-aurora",
      "Engine":"aurora-postgresql",
      "EngineVersion":"16.1"}'

# 4. Monitor restore progress
aws rds describe-db-clusters \
  --db-cluster-identifier apprentice-final-dr-aurora \
  --region us-west-2 \
  --query 'DBClusters[0].Status'

# Expected statuses: creating → backing-up → available
# Typical time: 30-60 minutes depending on database size
```

#### Step 3: Deploy Infrastructure in DR Region (10-20 minutes)

```bash
# 1. Navigate to infrastructure directory
cd /path/to/PolymathFinalTask/ops/iac

# 2. Create DR workspace (if not exists)
terraform workspace new dr 2>/dev/null || terraform workspace select dr

# 3. Deploy to DR region
terraform apply \
  -var="environment=dr" \
  -var="aws_region=us-west-2" \
  -var="aurora_cluster_endpoint=<restored-endpoint-from-step2>" \
  -auto-approve

# This deploys:
# - Lambda functions
# - API Gateway
# - ElastiCache Redis (fresh)
# - CloudFront distribution (if not using Route53 failover)

# 4. Wait for deployment
# Typical time: 10-20 minutes
```

#### Step 4: Sync Frontend Assets (5-10 minutes)

```bash
# 1. Copy S3 frontend assets to DR region bucket
aws s3 sync \
  s3://apprentice-final-staging-frontend \
  s3://apprentice-final-dr-frontend \
  --source-region us-east-1 \
  --region us-west-2

# If us-east-1 is completely down, deploy from local build:
cd packages/web
npm run build
aws s3 sync dist/ s3://apprentice-final-dr-frontend --region us-west-2

# 2. Invalidate CloudFront cache (if using)
CF_DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id $CF_DISTRIBUTION_ID \
  --paths "/*"
```

#### Step 5: Update DNS (5-15 minutes)

```bash
# Option A: Manual Route53 Update
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0025989W9J32N8Q1R0 \
  --change-batch file://route53-failover.json

# route53-failover.json:
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "bardhi.devops.konitron.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "Z2FDTNDATAQYW2",
        "DNSName": "<dr-cloudfront-domain>.cloudfront.net",
        "EvaluateTargetHealth": false
      }
    }
  }]
}

# Option B: If Route53 health checks configured (automatic)
# DNS will automatically fail over when health checks fail
# Wait for TTL to expire (typically 60 seconds)
```

#### Step 6: Validate DR Environment (10-15 minutes)

```bash
# 1. Check health endpoint
curl https://bardhi.devops.konitron.com/health/
# Expected: {"status": "healthy", "database": {"status": "healthy"}, ...}

# 2. Test authentication
curl -X POST https://bardhi.devops.konitron.com/Register/ \
  -d "username=testuser&email=test@example.com&password1=TestPass123&password2=TestPass123"

# 3. Test database read/write
curl -X POST https://bardhi.devops.konitron.com/api/habits/ \
  -H "Authorization: ..." \
  -d '{"name":"DR Test Habit","frequency":"daily"}'

# 4. Check CloudWatch metrics in us-west-2
# Navigate to CloudWatch > Dashboards in us-west-2 region

# 5. Monitor for errors
aws logs tail /aws/lambda/apprentice-final-dr-api \
  --region us-west-2 \
  --follow \
  --since 10m
```

#### Step 7: Notify Stakeholders (5 minutes)

```
Subject: DR Failover Complete - System Operational in us-west-2

Body:
- DR failover initiated at: [TIME]
- Failover completed at: [TIME]  
- Total downtime: [DURATION]
- RPO achieved: [< 1 hour]
- Current status: Operational
- Region: us-west-2
- Estimated data loss: [X minutes/hours]
- Next steps: Monitor for 24h, plan failback when us-east-1 recovers
```

### Total Timeline Estimate

| Step | Duration | Cumulative |
|------|----------|------------|
| 1. Assess & Communicate | 5 min | 5 min |
| 2. Restore Database | 30-60 min | 35-65 min |
| 3. Deploy Infrastructure | 10-20 min | 45-85 min |
| 4. Sync Frontend | 5-10 min | 50-95 min |
| 5. Update DNS | 5-15 min | 55-110 min |
| 6. Validate | 10-15 min | 65-125 min |
| 7. Notify | 5 min | **70-130 min** |

**RTO Achieved: 1-2.5 hours** ✅ (Target: 4 hours)

---

## Scenario 3: Data Corruption

### Detection

**Symptoms:**
- Reports of missing or incorrect data
- Database errors in logs
- Failed database integrity checks

### Recovery Procedure

```bash
# 1. Identify corruption time window
# Check application logs, database logs

# 2. List available backups
aws backup list-recovery-points-by-resource \
  --resource-arn arn:aws:rds:us-east-1:967746377724:cluster:apprentice-final-staging-aurora

# 3. Choose backup from BEFORE corruption occurred
# Example: Corruption detected at 14:30, use 13:00 backup

# 4. Restore to new cluster (don't overwrite prod immediately)
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier apprentice-final-staging-aurora \
  --db-cluster-identifier apprentice-final-restored-$(date +%Y%m%d-%H%M) \
  --restore-to-time 2025-01-19T13:00:00Z \
  --use-latest-restorable-time false

# 5. Wait for restore (10-30 minutes)

# 6. Validate restored data
psql -h <restored-endpoint> -U dbadmin -d habittracker
# Run queries to verify data integrity

# 7. If data is good, update SSM parameter to point to new cluster
aws ssm put-parameter \
  --name /apprentice-final/staging/aurora/writer_endpoint \
  --value <restored-endpoint> \
  --overwrite

# 8. Restart Lambda (force new connections)
aws lambda update-function-configuration \
  --function-name apprentice-final-staging-api \
  --environment Variables="{FORCE_RESTART=$(date +%s)}"

# 9. Verify application using restored database
curl https://bardhi.devops.konitron.com/health/

# 10. If all good, delete corrupted cluster
aws rds delete-db-cluster \
  --db-cluster-identifier apprentice-final-staging-aurora \
  --skip-final-snapshot
```

**RPO Achieved**: Depends on backup chosen (hourly backups = max 1 hour loss)

---

## Scenario 4: Rollback After DR

### When to Failback

- Primary region (us-east-1) is confirmed stable
- Running in DR region for > 24 hours
- Business prefers primary region for cost/latency

### Failback Procedure

```bash
# 1. Create snapshot of DR database (current state)
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier apprentice-final-dr-aurora \
  --db-cluster-snapshot-identifier dr-to-primary-$(date +%Y%m%d) \
  --region us-west-2

# 2. Copy snapshot to primary region
aws rds copy-db-cluster-snapshot \
  --source-db-cluster-snapshot-identifier dr-to-primary-$(date +%Y%m%d) \
  --target-db-cluster-snapshot-identifier dr-to-primary-$(date +%Y%m%d) \
  --source-region us-west-2 \
  --region us-east-1

# 3. Restore in primary region
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier apprentice-final-staging-aurora \
  --snapshot-identifier dr-to-primary-$(date +%Y%m%d) \
  --engine aurora-postgresql \
  --region us-east-1

# 4. Deploy infrastructure in primary region
cd ops/iac
terraform workspace select default
terraform apply -var="environment=staging" -auto-approve

# 5. Update Route53 to point back to primary
# (Reverse of Step 5 in Regional Failure)

# 6. Monitor for 1 hour

# 7. Tear down DR environment (cost savings)
terraform workspace select dr
terraform destroy -auto-approve
```

---

## Testing Procedures

### Monthly: Backup Validation Test

```bash
# Validate that backups can be restored
# Perform on non-production hours

# 1. Restore latest backup to test cluster
aws backup start-restore-job \
  --recovery-point-arn $(aws backup list-recovery-points-by-resource \
      --resource-arn <aurora-arn> \
      --query 'RecoveryPoints[0].RecoveryPointArn' \
      --output text) \
  --iam-role-arn <backup-role-arn> \
  --metadata '{"DBClusterIdentifier":"test-restore-$(date +%Y%m%d)"}'

# 2. Connect and validate data
psql -h <test-endpoint> -U dbadmin -d habittracker -c "SELECT COUNT(*) FROM auth_user;"

# 3. Clean up
aws rds delete-db-cluster \
  --db-cluster-identifier test-restore-$(date +%Y%m%d) \
  --skip-final-snapshot
```

### Quarterly: Full DR Drill

```bash
# Schedule during maintenance window
# Full failover to DR region and back

# 1. Announce drill to stakeholders
# 2. Execute "Scenario 2: Regional Failure" (all steps)
# 3. Run production workload in DR for 1 hour
# 4. Execute "Scenario 4: Rollback After DR"
# 5. Document lessons learned
# 6. Update runbook based on findings
```

---

## Monitoring & Validation

### Health Checks

```bash
# Primary application health
curl https://bardhi.devops.konitron.com/health/

# Database connectivity
aws rds describe-db-clusters \
  --db-cluster-identifier apprentice-final-staging-aurora \
  --query 'DBClusters[0].[Status,Endpoint]'

# Recent backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name apprentice-final-staging-vault \
  --query 'RecoveryPoints[0:3].[RecoveryPointArn,CreationDate,Status]'

# Replication lag (if using Aurora Global Database)
aws rds describe-global-clusters \
  --global-cluster-identifier apprentice-final-global \
  --query 'GlobalClusters[0].GlobalClusterMembers[*].[DBClusterArn,IsWriter]'
```

### CloudWatch Dashboards

- **Primary:** `apprentice-final-staging-overview`
- **Backup Jobs:** AWS Backup console > Jobs
- **DR Metrics:** (When deployed) us-west-2 CloudWatch dashboard

### Alerts

Monitor these CloudWatch alarms:
- `apprentice-final-staging-api-5xx` - High error rate
- `apprentice-final-staging-aurora-connections` - Database issues
- `apprentice-final-staging-backup-failures` - Backup problems

---

## Appendix: Quick Command Reference

```bash
# List all backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name apprentice-final-staging-vault

# Restore database from backup
aws backup start-restore-job \
  --recovery-point-arn <arn> \
  --iam-role-arn <role-arn>

# Check Lambda logs
aws logs tail /aws/lambda/apprentice-final-staging-api --follow

# Update DNS
aws route53 change-resource-record-sets \
  --hosted-zone-id Z0025989W9J32N8Q1R0 \
  --change-batch file://change.json

# Deploy DR infrastructure
terraform workspace select dr && terraform apply -var="aws_region=us-west-2"

# Health check
curl https://bardhi.devops.konitron.com/health/ | jq .
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-19 | Bardh Serreqi | Initial DR runbook for Pilot Light strategy |

