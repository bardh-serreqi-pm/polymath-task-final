# ============================================================================
# DISASTER RECOVERY: AWS Backup for Pilot Light Strategy
# ============================================================================
# Implements hourly snapshot backups with cross-region copying capability
# Target: RPO = 1 hour, RTO = 4 hours

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

    # Enable continuous backups (Point-in-Time Recovery)
    # Provides even better RPO (~5 minutes for Aurora)
    enable_continuous_backup = true

    # =========================================================================
    # Cross-Region Copy (DR Region: us-west-2)
    # =========================================================================
    # Uncomment when DR region infrastructure is deployed:
    #
    # copy_action {
    #   destination_vault_arn = "arn:aws:backup:us-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:${var.project_name}-${var.environment}-dr-vault"
    #   
    #   lifecycle {
    #     delete_after = 168  # Match primary retention
    #   }
    # }
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
      cold_storage_after = 30 # Move to cold storage after 30 days (cost optimization)
      delete_after       = 90 # Keep for 90 days total
    }
  }

  # Advanced backup settings
  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "enabled" # For Windows workloads (if applicable)
    }
    resource_type = "EC2"
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

output "backup_plan_id" {
  description = "ID of the Aurora DR backup plan"
  value       = aws_backup_plan.aurora_dr.id
}

output "backup_plan_arn" {
  description = "ARN of the Aurora DR backup plan"
  value       = aws_backup_plan.aurora_dr.arn
}

