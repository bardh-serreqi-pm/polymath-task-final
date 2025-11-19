# ============================================================================
# DISASTER RECOVERY: AWS Backup for Pilot Light Strategy
# ============================================================================
# Implements hourly snapshot backups with cross-region copying capability
# Target: RPO = 1 hour, RTO = 4 hours

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ============================================================================
# IAM Role for AWS Backup Service
# ============================================================================

resource "aws_iam_role" "backup" {
  name = "${var.project_name}-${var.environment}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-backup-role"
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# ============================================================================
# Backup Vault (Primary Region)
# ============================================================================

resource "aws_backup_vault" "primary" {
  name = "${var.project_name}-${var.environment}-vault"

  tags = merge(local.common_tags, {
    Name                         = "${var.project_name}-${var.environment}-vault"
    "disaster-recovery:location" = "primary"
    "disaster-recovery:type"     = "backup-vault"
  })
}

# Optional: Backup vault lock for compliance (uncomment if needed)
# resource "aws_backup_vault_lock_configuration" "primary" {
#   backup_vault_name   = aws_backup_vault.primary.name
#   min_retention_days  = 7
# }

# ============================================================================
# Backup Vault (DR Region - us-west-2)
# ============================================================================

resource "aws_backup_vault" "dr" {
  provider = aws.us_west_2
  name     = "${var.project_name}-${var.environment}-dr-vault"

  tags = merge(local.common_tags, {
    Name                         = "${var.project_name}-${var.environment}-dr-vault"
    "disaster-recovery:location" = "secondary"
    "disaster-recovery:region"   = "us-west-2"
    "disaster-recovery:type"     = "backup-vault"
  })
}

# ============================================================================
# Backup Plan: Hourly Snapshots (RPO = 1 hour)
# ============================================================================

resource "aws_backup_plan" "aurora_dr" {
  name = "${var.project_name}-${var.environment}-aurora-dr"

  # ============================================================================
  # Rule 1: Hourly Backups for RPO = 1 hour
  # ============================================================================
  rule {
    rule_name         = "hourly_backup_rpo_1h"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 * * * ? *)" # Every hour on the hour
    start_window      = 60                  # Start backup within 60 minutes of scheduled time
    completion_window = 120                 # Complete backup within 2 hours

    lifecycle {
      delete_after = 168 # 7 days retention (168 hours)
    }

    # Note: Continuous backups disabled for hourly snapshot-based backups
    # Aurora's native PITR (7-day retention) already provides RPO < 5 minutes
    # enable_continuous_backup = true

    # =========================================================================
    # Cross-Region Copy (DR Region: us-west-2)
    # =========================================================================
    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn

      lifecycle {
        delete_after = 168 # Match primary retention (7 days)
      }
    }
  }

  # ============================================================================
  # Rule 2: Daily Backups for Long-term Retention
  # ============================================================================
  rule {
    rule_name         = "daily_backup_long_term"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 3 * * ? *)" # 3 AM daily (low-traffic window)
    start_window      = 60
    completion_window = 120

    lifecycle {
      # Note: cold_storage_after removed - Aurora snapshots don't support cold storage
      delete_after = 90 # Keep for 90 days total
    }

    # =========================================================================
    # Cross-Region Copy (DR Region: us-west-2)
    # =========================================================================
    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn

      lifecycle {
        delete_after = 90 # Match primary retention (90 days)
      }
    }
  }

  tags = merge(local.common_tags, {
    Name                    = "${var.project_name}-${var.environment}-aurora-dr-plan"
    "disaster-recovery:rpo" = "1h"
    "disaster-recovery:rto" = "4h"
  })
}

# ============================================================================
# Backup Selection: Which Resources to Back Up
# ============================================================================

resource "aws_backup_selection" "aurora" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-${var.environment}-aurora-selection"
  plan_id      = aws_backup_plan.aurora_dr.id

  # Specific resource ARNs to back up
  resources = [
    aws_rds_cluster.aurora.arn
  ]

  # Tag-based selection: Only backup resources with this tag
  selection_tag {
    type  = "STRINGEQUALS"
    key   = "backup:automated"
    value = "true"
  }
}

# ============================================================================
# CloudWatch Alarm: Backup Job Failures
# ============================================================================

resource "aws_cloudwatch_metric_alarm" "backup_failures" {
  alarm_name          = "${var.project_name}-${var.environment}-backup-failures"
  alarm_description   = "Alert when AWS Backup jobs fail (DR risk)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  period              = 3600 # 1 hour

  metric_name = "NumberOfBackupJobsFailed"
  namespace   = "AWS/Backup"
  statistic   = "Sum"

  # Optional: Add SNS topic for notifications
  # alarm_actions = [var.sns_topic_arn]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-backup-failures-alarm"
  })
}

# ============================================================================
# S3 Bucket Versioning for Frontend (Static Assets DR)
# ============================================================================

resource "aws_s3_bucket_versioning" "frontend_dr" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled" # Enables point-in-time recovery for S3 objects
  }
}

# Optional: S3 Cross-Region Replication (uncomment when DR region is set up)
# resource "aws_s3_bucket_replication_configuration" "frontend_dr" {
#   bucket = aws_s3_bucket.frontend.id
#   role   = aws_iam_role.s3_replication.arn
#
#   rule {
#     id     = "replicate-to-dr"
#     status = "Enabled"
#
#     destination {
#       bucket        = "arn:aws:s3:::${var.project_name}-${var.environment}-frontend-dr"
#       storage_class = "STANDARD_IA"  # Cost optimization in DR region
#
#       # Replication Time Control for predictable RPO
#       replication_time {
#         status = "Enabled"
#         time {
#           minutes = 15  # 99.99% replicated within 15 minutes
#         }
#       }
#
#       metrics {
#         status = "Enabled"
#         event_threshold {
#           minutes = 15
#         }
#       }
#     }
#   }
# }

# ============================================================================
# Outputs for Backup Resources
# ============================================================================

output "backup_vault_arn" {
  description = "ARN of the primary backup vault"
  value       = aws_backup_vault.primary.arn
}

output "backup_vault_dr_arn" {
  description = "ARN of the DR backup vault (us-west-2)"
  value       = aws_backup_vault.dr.arn
}

output "backup_plan_id" {
  description = "ID of the Aurora DR backup plan"
  value       = aws_backup_plan.aurora_dr.id
}

output "backup_plan_arn" {
  description = "ARN of the Aurora DR backup plan"
  value       = aws_backup_plan.aurora_dr.arn
}

