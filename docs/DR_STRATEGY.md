# Disaster Recovery Strategy

## Overview

This document outlines the High Availability and Disaster Recovery strategy for the Apprentice Final Project.

**Requirements:**
- **RTO (Recovery Time Objective)**: 4 hours maximum
- **RPO (Recovery Point Objective)**: 1 hour maximum

**Strategy:** Multi-AZ High Availability + Pilot Light Multi-Region Disaster Recovery

---

## Architecture Overview

### Primary Region: us-east-1
- **Production Environment**: Fully operational
- **Compute**: Lambda functions in multiple AZs
- **Database**: Aurora Serverless v2 with multi-AZ deployment
- **Cache**: ElastiCache Serverless with multi-AZ
- **Storage**: S3 with versioning enabled
- **CDN**: CloudFront global distribution

### Secondary Region: us-west-2 (Pilot Light)
- **Minimal Resources**: Database replica, infrastructure templates ready
- **Cost-Optimized**: Only critical data replication active
- **Activation Time**: Can be promoted to production in < 4 hours

---

## 1. High Availability (Within Region)

### 1.1 Multi-AZ Deployment

**Automatically Multi-AZ:**
- ✅ AWS Lambda (runs across all AZs in region)
- ✅ API Gateway (regional service)
- ✅ S3 (replicates across 3+ AZs)
- ✅ CloudFront (global edge network)

**Requires Configuration:**

#### Aurora Multi-AZ Setup
```hcl
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.project_name}-${var.environment}-aurora"
  engine                  = "aurora-postgresql"
  engine_mode            = "provisioned"
  
  # Multi-AZ Configuration
  availability_zones      = data.aws_availability_zones.available.names
  
  # High Availability Settings
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  
  # Automatic failover enabled by default
  # Failover time: 1-2 minutes
}

# Multi-AZ instances
resource "aws_rds_cluster_instance" "aurora_instances" {
  count              = 2  # One in each AZ
  identifier         = "${var.project_name}-${var.environment}-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  
  # Spread across AZs
  availability_zone  = element(data.aws_availability_zones.available.names, count.index)
}
```

#### ElastiCache Multi-AZ Setup
```hcl
resource "aws_elasticache_serverless_cache" "redis" {
  engine = "redis"
  name   = "${var.project_name}-${var.environment}-redis"
  
  # Multi-AZ Configuration for Redis Serverless
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
  }
  
  # Subnet group spans multiple AZs
  subnet_ids = var.private_subnet_ids
  
  # Automatic failover enabled
}
```

### 1.2 Current HA Status

| Component | HA Status | Failover Time | Notes |
|-----------|-----------|---------------|-------|
| Lambda | ✅ Multi-AZ | < 1 second | Automatic |
| API Gateway | ✅ Multi-AZ | < 1 second | Regional service |
| Aurora | ⚠️ Needs Config | 1-2 minutes | Enable multi-AZ |
| ElastiCache | ⚠️ Needs Config | 1-2 minutes | Use multi-AZ subnets |
| S3 | ✅ Multi-AZ | < 1 second | Automatic |
| CloudFront | ✅ Global | < 1 second | Edge caching |

---

## 2. Disaster Recovery (Cross-Region)

### 2.1 Strategy: Pilot Light

**Cost-Effective DR for RTO = 4h, RPO = 1h**

#### What's Running in Secondary Region (Pilot Light):
1. **Database Replica**: Aurora Global Database (read-only)
2. **S3 Bucket**: Cross-region replication (passive)
3. **Infrastructure Code**: Terraform modules ready to deploy
4. **Minimal Compute**: No Lambda/API Gateway (deployed on demand)

#### What's NOT Running (Cost Savings):
- Lambda functions (deployed during failover)
- API Gateway (created during failover)
- CloudFront distribution (switched via Route53)
- ElastiCache (provisioned during failover)

### 2.2 Implementation

#### Option A: Aurora Global Database (Recommended)

**Best for your use case - meets both RTO and RPO with margin**

```hcl
# ============================================================================
# Primary Region (us-east-1)
# ============================================================================

# Global cluster
resource "aws_rds_global_cluster" "habit_tracker" {
  global_cluster_identifier = "${var.project_name}-global"
  engine                    = "aurora-postgresql"
  engine_version            = "16.1"
  database_name             = var.db_name
  
  # Force new resource on destroy
  lifecycle {
    create_before_destroy = true
  }
}

# Primary cluster
resource "aws_rds_cluster" "aurora_primary" {
  cluster_identifier        = "${var.project_name}-${var.environment}-primary"
  global_cluster_identifier = aws_rds_global_cluster.habit_tracker.id
  
  engine         = "aurora-postgresql"
  engine_version = "16.1"
  
  # Multi-AZ within region
  availability_zones = data.aws_availability_zones.available.names
  
  # Backup configuration (RPO < 5 minutes with PITR)
  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # High availability
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 4
  }
}

# ============================================================================
# Secondary Region (us-west-2) - Pilot Light
# ============================================================================

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

# Secondary (replica) cluster
resource "aws_rds_cluster" "aurora_secondary" {
  provider = aws.us_west_2
  
  cluster_identifier        = "${var.project_name}-${var.environment}-secondary"
  global_cluster_identifier = aws_rds_global_cluster.habit_tracker.id
  
  engine         = "aurora-postgresql"
  engine_version = "16.1"
  
  # Replica lag: < 1 second (typically milliseconds)
  # RPO: Effectively < 1 second!
  
  # Cost optimization: Start with minimal capacity
  serverlessv2_scaling_configuration {
    min_capacity = 0.5  # Scale up during failover
    max_capacity = 4
  }
  
  # This is a read replica until promoted
  replication_source_identifier = aws_rds_cluster.aurora_primary.arn
  
  depends_on = [aws_rds_cluster_instance.aurora_primary]
}
```

**Performance Characteristics:**
- **RPO: < 1 second** (continuous async replication)
- **Replication Lag**: Typically 100-300ms
- **Failover RTO**: 
  - Promote secondary: 1-2 minutes
  - Deploy Lambda/API Gateway: 5-10 minutes
  - Update DNS: 5-15 minutes (TTL dependent)
  - **Total: 15-30 minutes** (well under 4h requirement)

**Cost:**
- Primary region: Normal costs
- Secondary region: ~50% of primary (read replica only)
- **Total increase: ~50%** over single region

#### Option B: Snapshot-Based DR (Lower Cost)

```hcl
# Automated snapshot copy to DR region
resource "aws_backup_plan" "dr_backup" {
  name = "${var.project_name}-dr-backup"

  rule {
    rule_name         = "hourly_snapshot_copy"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 * * * ? *)"  # Every hour
    
    lifecycle {
      delete_after = 168  # 7 days
    }
    
    # Copy to DR region
    copy_action {
      destination_vault_arn = "arn:aws:backup:us-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:${var.project_name}-dr"
      
      lifecycle {
        delete_after = 168
      }
    }
  }
}

resource "aws_backup_selection" "aurora_backup" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-aurora-selection"
  plan_id      = aws_backup_plan.dr_backup.id

  resources = [
    aws_rds_cluster.aurora.arn
  ]
}
```

**Performance Characteristics:**
- **RPO: 1 hour** (snapshot frequency)
- **Failover RTO**:
  - Restore snapshot: 30-60 minutes
  - Deploy infrastructure: 10-20 minutes
  - Update DNS: 5-15 minutes
  - **Total: 45-95 minutes** (well under 4h)

**Cost:**
- Secondary region: Only snapshot storage
- **Total increase: ~10-15%** over single region

### 2.3 S3 Cross-Region Replication

```hcl
# Frontend bucket replication (static assets)
resource "aws_s3_bucket_replication_configuration" "frontend_dr" {
  bucket = aws_s3_bucket.frontend.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = "arn:aws:s3:::${var.project_name}-${var.environment}-frontend-dr"
      storage_class = "STANDARD_IA"  # Cost optimization
      
      # Replication time control for predictable RPO
      replication_time {
        status = "Enabled"
        time {
          minutes = 15  # 99.99% replicated within 15 minutes
        }
      }
      
      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }
  }
}
```

### 2.4 Route53 Failover Configuration

```hcl
# Health check for primary region
resource "aws_route53_health_check" "primary" {
  fqdn              = var.frontend_domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health/"
  failure_threshold = 3
  request_interval  = 30
  
  tags = {
    Name = "${var.project_name}-primary-health"
  }
}

# Primary record (active)
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.frontend_domain_name
  type    = "A"
  
  alias {
    name                   = module.edge.cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2"  # CloudFront zone ID
    evaluate_target_health = true
  }
  
  set_identifier = "primary"
  
  failover_routing_policy {
    type = "PRIMARY"
  }
  
  health_check_id = aws_route53_health_check.primary.id
}

# Secondary record (standby)
resource "aws_route53_record" "secondary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.frontend_domain_name
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.dr.domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
  
  set_identifier = "secondary"
  
  failover_routing_policy {
    type = "SECONDARY"
  }
}
```

---

## 3. Backup Strategy

### 3.1 Automated Backups

| Resource | Frequency | Retention | RPO | Location |
|----------|-----------|-----------|-----|----------|
| Aurora | Continuous | 7 days | < 5 min | us-east-1, us-west-2 |
| Aurora Snapshots | Hourly | 7 days | 1 hour | us-west-2 |
| S3 (Versioning) | Real-time | 30 days | < 1 min | us-east-1, us-west-2 |
| Infrastructure | Git commit | Forever | 0 | GitHub |
| Lambda Code | ECR tags | 90 days | 0 | us-east-1, us-west-2 |

### 3.2 Point-in-Time Recovery

Aurora enables PITR for any point within the backup retention period:

```bash
# Restore to specific timestamp
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier apprentice-final-staging-aurora \
  --db-cluster-identifier apprentice-final-restored \
  --restore-to-time 2025-01-15T14:30:00Z
```

---

## 4. Failover Procedures

### 4.1 Automated Failover (Regional Failure)

**Scenario**: Primary region (us-east-1) becomes unavailable

**Automatic Actions** (Route53 health check fails):
1. Route53 detects health check failure (90 seconds)
2. DNS fails over to secondary record (TTL: 60 seconds)
3. Traffic routes to DR region

**Manual Actions Required** (within 4 hours):
1. **Promote Aurora secondary** (if using Global Database):
   ```bash
   aws rds remove-from-global-cluster \
     --db-cluster-identifier apprentice-final-staging-secondary \
     --region us-west-2
   
   # Secondary is now read-write (2-5 minutes)
   ```

2. **Deploy compute resources**:
   ```bash
   cd ops/iac
   terraform workspace select dr
   terraform apply -var="environment=dr" -var="aws_region=us-west-2"
   # Deploys Lambda, API Gateway, ElastiCache (10-15 minutes)
   ```

3. **Update CloudFront origin**:
   ```bash
   # Update CloudFront to point to new API Gateway in us-west-2
   terraform apply -target=module.edge
   ```

4. **Verify and test**:
   ```bash
   curl https://bardhi.devops.konitron.com/health/
   # Should return healthy from us-west-2
   ```

**Total Time**: 15-30 minutes (well under 4h RTO)

### 4.2 Database-Only Failure

**Scenario**: Aurora primary cluster fails, but region is healthy

**Automatic Actions**:
- Aurora Multi-AZ automatic failover (1-2 minutes)
- Application continues with minimal disruption

**No manual intervention required**

### 4.3 Data Corruption / Accidental Deletion

**Scenario**: Bad deployment corrupts data

**Manual Recovery**:
1. **Identify last good backup point**:
   ```bash
   aws rds describe-db-cluster-snapshots \
     --db-cluster-identifier apprentice-final-staging-aurora
   ```

2. **Restore to new cluster**:
   ```bash
   aws rds restore-db-cluster-from-snapshot \
     --db-cluster-identifier apprentice-final-restored \
     --snapshot-identifier apprentice-final-snapshot-2025-01-15 \
     --engine aurora-postgresql
   ```

3. **Validate data integrity**:
   ```bash
   # Connect and verify data
   psql -h <restored-endpoint> -U dbadmin -d habittracker
   ```

4. **Switch application** (update SSM parameter):
   ```bash
   aws ssm put-parameter \
     --name /apprentice-final/staging/database/writer_endpoint \
     --value <restored-endpoint> \
     --overwrite
   
   # Restart Lambda (automatic on next invocation)
   ```

**Total Time**: 1-2 hours (within RTO)

---

## 5. Testing Strategy

### 5.1 DR Drills (Quarterly)

**Test 1: Regional Failover**
- Simulate primary region failure
- Execute failover procedures
- Measure RTO and RPO
- Document issues and improvements

**Test 2: Database Restoration**
- Restore from snapshot to test cluster
- Verify data integrity
- Measure restoration time

**Test 3: Application Recovery**
- Deploy infrastructure from scratch in DR region
- Restore application state
- End-to-end functionality testing

### 5.2 Monitoring DR Readiness

```hcl
# CloudWatch alarm for replication lag
resource "aws_cloudwatch_metric_alarm" "aurora_replication_lag" {
  alarm_name          = "${var.project_name}-aurora-replication-lag"
  alarm_description   = "Alert when Aurora replication lag exceeds 1 hour (RPO risk)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 3600000  # 1 hour in milliseconds
  
  metric_name = "AuroraGlobalDBReplicationLag"
  namespace   = "AWS/RDS"
  period      = 300
  statistic   = "Average"
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora_secondary.id
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Alarm for backup failures
resource "aws_cloudwatch_metric_alarm" "backup_failure" {
  alarm_name          = "${var.project_name}-backup-failures"
  alarm_description   = "Alert when automated backups fail"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  
  metric_name = "NumberOfFailedBackupJobs"
  namespace   = "AWS/Backup"
  period      = 300
  statistic   = "Sum"
  
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## 6. Cost Analysis

### 6.1 Option A: Aurora Global Database

| Component | Primary Region | DR Region | Total Monthly |
|-----------|----------------|-----------|---------------|
| Aurora Primary | $50 | - | $50 |
| Aurora Secondary | - | $25 | $25 |
| Data Transfer (out) | $5 | - | $5 |
| S3 Replication | $2 | $1 | $3 |
| **Total** | | | **$83/month** |

**Cost increase**: ~50% for comprehensive DR

### 6.2 Option B: Snapshot-Based

| Component | Primary Region | DR Region | Total Monthly |
|-----------|----------------|-----------|---------------|
| Aurora Primary | $50 | - | $50 |
| Snapshot Storage | - | $3 | $3 |
| Data Transfer | $2 | - | $2 |
| S3 Replication | $2 | $1 | $3 |
| **Total** | | | **$58/month** |

**Cost increase**: ~15% for basic DR

### 6.3 Recommendation

**For RTO = 4h, RPO = 1h**: 
- **Option B (Snapshot-Based)** is sufficient and cost-effective
- Provides adequate recovery capability
- Saves ~$25/month compared to Global Database

**Upgrade to Option A if**:
- RPO requirement becomes < 15 minutes
- RTO requirement becomes < 1 hour
- Business criticality increases

---

## 7. Recovery Procedures Summary

| Failure Scenario | Detection Time | Recovery Time | RPO | RTO | Meets Requirements? |
|------------------|----------------|---------------|-----|-----|---------------------|
| AZ failure (Multi-AZ) | < 1 min | 1-2 min | 0 | < 5 min | ✅ |
| Regional failure (Pilot Light) | 1-2 min | 30-90 min | 1 hour | < 2 hours | ✅ |
| Data corruption | Manual | 1-2 hours | 1 hour | 1-2 hours | ✅ |
| Complete disaster | Manual | 2-4 hours | 1 hour | 2-4 hours | ✅ |

**All scenarios meet or exceed the RTO = 4h, RPO = 1h requirements** ✅

---

## 8. Implementation Checklist

- [ ] Enable Multi-AZ for Aurora cluster
- [ ] Configure Aurora automated backups (hourly)
- [ ] Set up AWS Backup plan with cross-region copy
- [ ] Enable S3 versioning on frontend bucket
- [ ] Configure S3 cross-region replication
- [ ] Set up Route53 health checks
- [ ] Configure Route53 failover routing
- [ ] Create Terraform workspace for DR region
- [ ] Deploy minimal DR infrastructure (Pilot Light)
- [ ] Document failover procedures in RUNBOOK.md
- [ ] Schedule quarterly DR drills
- [ ] Set up CloudWatch alarms for DR metrics
- [ ] Train team on failover procedures
- [ ] Test restore from backup
- [ ] Update monitoring dashboard with DR metrics

---

## 9. Next Steps

1. **Immediate** (This Sprint):
   - Enable Multi-AZ for Aurora and ElastiCache
   - Configure automated hourly backups
   - Set up S3 versioning

2. **Short Term** (Next Sprint):
   - Implement cross-region snapshot copying
   - Create Terraform workspace for DR region
   - Document detailed failover procedures

3. **Medium Term** (Next Month):
   - Conduct first DR drill
   - Set up Route53 failover routing
   - Deploy Pilot Light infrastructure

4. **Long Term** (Quarterly):
   - Regular DR testing
   - Review and update procedures
   - Optimize costs

---

## 10. References

- [AWS Aurora Global Database](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- [AWS Backup](https://docs.aws.amazon.com/aws-backup/)
- [Route53 Failover Routing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-failover.html)
- [Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/)

