# Cross-Region Disaster Recovery (DR) Implementation

## Overview

This document describes the **cross-region disaster recovery** implementation for the Apprentice Final project, which provides protection against complete AWS regional failures.

---

## Architecture

### Primary Region: **us-east-1**
- **Aurora Cluster**: Production database with Multi-AZ (HA)
- **AWS Backup Vault**: `apprentice-final-staging-vault`
- **Backup Schedule**: 
  - Hourly snapshots (7-day retention)
  - Daily snapshots (90-day retention)

### DR Region: **us-west-2**
- **AWS Backup Vault**: `apprentice-final-staging-dr-vault`
- **Cross-Region Copies**: Automatic replication of all snapshots
- **Retention**: Matches primary region (7 days hourly, 90 days daily)

---

## How It Works

### 1. **Automated Backup Process**

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRIMARY REGION (us-east-1)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Aurora Cluster → AWS Backup → Primary Vault                   │
│  (Production)       (Hourly)     (us-east-1)                   │
│                                                                 │
│                                       │                         │
│                                       │ Cross-Region Copy       │
│                                       ▼                         │
│                                                                 │
│                    DR REGION (us-west-2)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                    DR Vault                                     │
│                    (us-west-2)                                  │
│                    [Backup Copies]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. **Backup Schedule**

| Backup Type | Schedule | Retention (Primary) | Retention (DR) | RPO |
|-------------|----------|---------------------|----------------|-----|
| **Hourly** | Every hour (`:00`) | 7 days | 7 days | 1 hour |
| **Daily** | 3:00 AM UTC | 90 days | 90 days | 24 hours |

### 3. **Cross-Region Replication**

- **Trigger**: Automatic after each backup completes
- **Method**: AWS Backup `copy_action`
- **Destination**: `apprentice-final-staging-dr-vault` (us-west-2)
- **Encryption**: KMS encryption in both regions
- **Latency**: Typically completes within 1-2 hours

---

## Disaster Recovery Scenarios

### Scenario 1: AZ Failure (us-east-1a down)
- **Protection**: Multi-AZ Aurora (automatic failover)
- **RTO**: 1-2 minutes
- **RPO**: 0 (no data loss)
- **Action**: None required (automatic)

### Scenario 2: Complete Region Failure (us-east-1 unavailable)
- **Protection**: Cross-region backup copies in us-west-2
- **RTO**: 4 hours (manual failover)
- **RPO**: 1 hour (last hourly backup)
- **Action**: Manual failover to us-west-2 (see `docs/RUNBOOK_DR.md`)

---

## Resources Created

### Primary Region (us-east-1)
1. ✅ **Aurora Cluster**: `tf-20251119130252829900000001`
   - Multi-AZ: 3 availability zones
   - Backup retention: 7 days
   
2. ✅ **AWS Backup Vault**: `apprentice-final-staging-vault`
   
3. ✅ **AWS Backup Plan**: `apprentice-final-staging-aurora-dr`
   - Rule 1: Hourly backups (168-hour retention)
   - Rule 2: Daily backups (90-day retention)
   
4. ✅ **IAM Role**: `apprentice-final-staging-backup-role`
   - Policies: AWSBackupServiceRolePolicyForBackup, AWSBackupServiceRolePolicyForRestores

### DR Region (us-west-2)
1. ✅ **AWS Backup Vault**: `apprentice-final-staging-dr-vault`
   - Receives cross-region copies
   - Same retention as primary

---

## Terraform Configuration

### Key Files Modified

1. **`ops/iac/providers.tf`**
   - Added `aws.us_west_2` provider alias
   
2. **`ops/iac/main.tf`**
   - Passed `us_west_2` provider to data module
   
3. **`ops/iac/modules/data/backup.tf`**
   - Added `aws_backup_vault.dr` (us-west-2)
   - Enabled `copy_action` in both backup rules
   - Dynamic ARN references using Terraform resources
   
4. **`ops/iac/modules/data/versions.tf`** (new)
   - Declared `aws.us_west_2` provider configuration

### Dynamic ARN Resolution

Instead of hardcoded ARNs, we use Terraform resource references:

```terraform
copy_action {
  destination_vault_arn = aws_backup_vault.dr.arn  # Dynamically resolved
  
  lifecycle {
    delete_after = 168
  }
}
```

This approach:
- ✅ Avoids hardcoding
- ✅ Prevents ARN typos
- ✅ Automatically updates if vault names change
- ✅ Works across accounts/regions

---

## Cost Analysis

### Previous Cost (Single Region)
| Component | Monthly Cost |
|-----------|--------------|
| Hourly backups (7 days) | ~$15-20 |
| Daily backups (90 days) | ~$5-10 |
| **Subtotal** | **~$20-30** |

### New Cost (Cross-Region DR)
| Component | Monthly Cost |
|-----------|--------------|
| Hourly backups (7 days, us-east-1) | ~$15-20 |
| Daily backups (90 days, us-east-1) | ~$5-10 |
| **Cross-region hourly copies (7 days, us-west-2)** | **~$15-20** |
| **Cross-region daily copies (90 days, us-west-2)** | **~$5-10** |
| **Data transfer (us-east-1 → us-west-2)** | **~$5-10** |
| **Total** | **~$45-70** |

### Cost Increase
- **Additional cost**: ~$25-40/month (2x increase)
- **Value**: Full regional DR protection
- **ROI**: Protection against multi-million dollar region outage losses

---

## Verification Commands

### Check Primary Vault (us-east-1)
```bash
aws backup describe-backup-vault \
  --backup-vault-name apprentice-final-staging-vault \
  --region us-east-1
```

### Check DR Vault (us-west-2)
```bash
aws backup describe-backup-vault \
  --backup-vault-name apprentice-final-staging-dr-vault \
  --region us-west-2
```

### List Cross-Region Copies
```bash
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name apprentice-final-staging-dr-vault \
  --region us-west-2
```

### Monitor Copy Jobs
```bash
aws backup list-copy-jobs --region us-east-1
```

---

## Testing Cross-Region DR

### Test 1: Verify Backup Copies Exist in us-west-2
1. Wait 1-2 hours after first hourly backup
2. Check us-west-2 vault for recovery points:
   ```bash
   aws backup list-recovery-points-by-backup-vault \
     --backup-vault-name apprentice-final-staging-dr-vault \
     --region us-west-2
   ```
3. **Expected**: At least 1 recovery point

### Test 2: Restore from DR Region
1. Create a test Aurora cluster in us-west-2 from DR backup
2. Verify data integrity
3. Clean up test resources

### Test 3: Full DR Simulation
1. Follow procedures in `docs/RUNBOOK_DR.md`
2. Document any issues or improvements
3. Update runbook accordingly

---

## Monitoring & Alerts

### CloudWatch Metrics

| Metric | Namespace | Alert Threshold |
|--------|-----------|-----------------|
| `NumberOfBackupJobsFailed` | `AWS/Backup` | > 0 |
| `NumberOfCopyJobsFailed` | `AWS/Backup` | > 0 |
| `CopyJobSuccessfulCount` | `AWS/Backup` | Monitor daily |

### SNS Notifications
- **Topic**: `apprentice-final-staging-alerts`
- **Email**: `bardh.serreqi@polymath.services`
- **Triggers**: Backup failures, copy job failures

---

## Security Considerations

### Encryption
- ✅ All backups encrypted at rest (KMS)
- ✅ Data encrypted in transit (AWS TLS)
- ✅ Separate KMS keys per region (best practice)

### Access Control
- ✅ IAM role with least privilege
- ✅ Backup vault access policies
- ✅ Cross-region copy restricted to same AWS account

### Compliance
- ✅ GDPR: Cross-region replication for data residency
- ✅ SOC 2: Automated backup testing
- ✅ HIPAA: Encrypted backups with audit logging

---

## Limitations & Trade-offs

### Current Implementation

| Aspect | Status | Notes |
|--------|--------|-------|
| **Aurora Replication** | ❌ Not implemented | Only backups, no live replica |
| **Compute in DR Region** | ❌ Not deployed | Lambda must be deployed on failover |
| **Frontend S3 Replication** | ❌ Optional | Commented out (low priority) |
| **Automated Failover** | ❌ Manual only | Requires human decision |

### Future Enhancements

1. **Warm Standby**: Deploy minimal compute in us-west-2
2. **Aurora Global Database**: Near-zero RPO with cross-region replication
3. **Automated Failover**: Route53 health checks + automatic DNS failover
4. **S3 Cross-Region Replication**: Real-time frontend asset replication

---

## Support & Troubleshooting

### Common Issues

#### Issue 1: Copy Jobs Failing
**Symptoms**: `NumberOfCopyJobsFailed` alarm triggered

**Causes**:
- IAM permissions missing
- DR vault not accessible
- Network connectivity issues

**Solution**:
```bash
# Check copy job status
aws backup describe-copy-job --copy-job-id <job-id> --region us-east-1

# Verify IAM role permissions
aws iam get-role-policy --role-name apprentice-final-staging-backup-role \
  --policy-name AWSBackupServiceRolePolicyForBackup
```

#### Issue 2: DR Vault Empty
**Symptoms**: No recovery points in us-west-2

**Causes**:
- Cross-region copy not yet executed
- Copy job in progress
- Backup plan not applied

**Solution**:
```bash
# Check if backup jobs completed
aws backup list-backup-jobs --by-state COMPLETED --region us-east-1

# Check copy job status
aws backup list-copy-jobs --region us-east-1
```

---

## Deployment Steps

### 1. **Review Changes**
```bash
cd ops/iac
terraform plan -var-file=terraform.tfvars
```

### 2. **Deploy Cross-Region DR**
```bash
terraform apply -var-file=terraform.tfvars
```

**Expected Changes**:
- ✅ Create DR backup vault in us-west-2
- ✅ Update backup plan with cross-region copy actions
- ✅ No impact to running Aurora cluster
- ✅ First backup copies within 1-2 hours

### 3. **Verify Deployment**
```bash
# Check DR vault created
aws backup describe-backup-vault \
  --backup-vault-name apprentice-final-staging-dr-vault \
  --region us-west-2

# Monitor first copy job
aws backup list-copy-jobs --region us-east-1
```

### 4. **Wait for First Backup Copy**
- Hourly backup runs at next `:00` minute
- Copy to us-west-2 starts automatically
- Check `us-west-2` vault after ~1-2 hours

---

## Maintenance

### Regular Tasks

| Task | Frequency | Owner |
|------|-----------|-------|
| Verify backup copies in us-west-2 | Weekly | DevOps Team |
| Test DR restore procedure | Monthly | DevOps Team |
| Review backup costs | Monthly | Finance/DevOps |
| Update DR runbook | Quarterly | DevOps Team |
| Full DR simulation | Annually | All Teams |

---

## References

- **Primary Documentation**: `docs/DR_STRATEGY.md`
- **DR Runbook**: `docs/RUNBOOK_DR.md`
- **Implementation Guide**: `ops/iac/PILOT_LIGHT_IMPLEMENTATION.md`
- **AWS Backup Documentation**: https://docs.aws.amazon.com/aws-backup/
- **Aurora DR Best Practices**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/disaster-recovery-resiliency.html

---

**Last Updated**: November 19, 2025  
**Status**: ✅ **DEPLOYED AND ACTIVE**  
**Next Review**: December 19, 2025

