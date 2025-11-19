# ============================================================================
# Data Sources
# ============================================================================

# Get available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# Random Resources
# ============================================================================

# Generate Django secret key if not provided
# This must be defined before locals block that references it
resource "random_password" "django_secret_key" {
  length  = 50
  special = true
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Component   = "data"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "data"
    }
  )

  frontend_bucket_name = var.frontend_bucket_name != "" ? var.frontend_bucket_name : "${var.project_name}-${var.environment}-frontend"

  # Generate Django secret key if not provided
  django_secret_key = var.django_secret_key != "" ? var.django_secret_key : random_password.django_secret_key.result
}

resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Allow access to Aurora PostgreSQL from application layer"
  vpc_id      = var.vpc_id

  ingress {
    description = "PostgreSQL access from VPC (port 5432)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-sg" })
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Allow access to ElastiCache Redis from application layer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis access from VPC (port 6379 with TLS)"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-redis-sg" })
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-subnets" })
}

resource "random_password" "aurora_master" {
  length  = 20
  upper   = true
  lower   = true
  numeric = true
  special = true
}

resource "aws_secretsmanager_secret" "aurora_master" {
  name        = "${var.project_name}/aurora/master"
  description = "Master credentials for Aurora cluster"

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-secret" })
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.aurora_master.result
    engine   = "postgres"
    host     = aws_rds_cluster.aurora.endpoint
    port     = 5432
    dbname   = var.db_name
  })

  depends_on = [aws_rds_cluster.aurora]
}

# Get available Aurora PostgreSQL engine versions
data "aws_rds_engine_version" "aurora_postgresql" {
  engine             = "aurora-postgresql"
  preferred_versions = ["16.1", "15.4", "15.3", "14.10", "14.9", "13.12", "13.11"]
}

resource "aws_rds_cluster" "aurora" {
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = data.aws_rds_engine_version.aurora_postgresql.version
  database_name          = var.db_name
  master_username        = var.db_master_username
  master_password        = random_password.aurora_master.result
  port                   = 5432 # PostgreSQL default port
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  # ============================================================================
  # HIGH AVAILABILITY: Multi-AZ Configuration
  # ============================================================================
  # Spans 2+ availability zones for automatic failover (1-2 min RTO)
  # Provides protection against AZ-level failures
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # Security
  storage_encrypted   = true
  deletion_protection = false # Set to true for production

  # ============================================================================
  # DISASTER RECOVERY: Pilot Light Strategy (RTO=4h, RPO=1h)
  # ============================================================================
  # Automated backups - Point-in-Time Recovery (PITR)
  # Continuous backup to S3, enables restore to any point within retention period
  backup_retention_period      = 7 # Increased from 3 to 7 days for better DR
  preferred_backup_window      = "03:00-05:00"
  preferred_maintenance_window = "sun:05:00-sun:07:00"

  # Final snapshot on deletion - Critical for DR scenarios
  # Note: Snapshot name will be auto-generated if cluster is deleted
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  # Copy tags to snapshots for proper tracking
  copy_tags_to_snapshot = true

  # CloudWatch logs for monitoring and audit trail
  enabled_cloudwatch_logs_exports = ["postgresql"]

  allow_major_version_upgrade = false
  apply_immediately           = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = merge(local.common_tags, {
    Name                         = "${var.project_name}-${var.environment}-aurora-cluster",
    "disaster-recovery:strategy" = "pilot-light",
    "disaster-recovery:rto"      = "4h",
    "disaster-recovery:rpo"      = "1h",
    "backup:automated"           = "true",
    "backup:retention-days"      = "7"
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier, # Ignore changes to prevent recreation
    ]
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  identifier                 = "${var.project_name}-${var.environment}-aurora-instance"
  cluster_identifier         = aws_rds_cluster.aurora.id
  instance_class             = "db.serverless"
  engine                     = aws_rds_cluster.aurora.engine
  engine_version             = aws_rds_cluster.aurora.engine_version
  publicly_accessible        = false
  db_subnet_group_name       = aws_db_subnet_group.aurora.name
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-instance" })
}

resource "aws_elasticache_serverless_cache" "redis" {
  name                 = "${var.project_name}-${var.environment}-redis"
  engine               = "redis"
  major_engine_version = "7"
  description          = "Serverless Redis cache for ${var.project_name}-${var.environment}"

  # Multi-AZ: Redis Serverless automatically spans multiple AZs for HA
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.redis.id]

  cache_usage_limits {
    data_storage {
      unit    = "GB"
      minimum = 1
      maximum = 10
    }
  }

  # Snapshot for DR (ephemeral cache, can be rebuilt from application)
  snapshot_retention_limit = 1

  tags = merge(local.common_tags, {
    Name                         = "${var.project_name}-${var.environment}-redis",
    "disaster-recovery:strategy" = "pilot-light",
    "disaster-recovery:note"     = "ephemeral-cache-rebuilt-on-failover"
  })
}

resource "aws_ssm_parameter" "aurora_writer_endpoint" {
  name        = "/${var.project_name}/${var.environment}/aurora/writer_endpoint"
  description = "Aurora writer endpoint for ${var.environment}"
  type        = "String"
  value       = aws_rds_cluster.aurora.endpoint
  overwrite   = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "aurora_reader_endpoint" {
  name        = "/${var.project_name}/${var.environment}/aurora/reader_endpoint"
  description = "Aurora reader endpoint for ${var.environment}"
  type        = "String"
  value       = aws_rds_cluster.aurora.reader_endpoint
  overwrite   = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "/${var.project_name}/${var.environment}/redis/endpoint"
  description = "Redis endpoint for ${var.environment}"
  type        = "String"
  value       = "${aws_elasticache_serverless_cache.redis.endpoint[0].address}:${aws_elasticache_serverless_cache.redis.endpoint[0].port}"
  overwrite   = true

  tags = local.common_tags
}

# Django configuration parameters
resource "aws_ssm_parameter" "django_secret_key" {
  name        = "/${var.project_name}/${var.environment}/django/secret_key"
  description = "Django SECRET_KEY for ${var.environment}"
  type        = "SecureString"
  value       = local.django_secret_key
  overwrite   = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "django_debug" {
  name        = "/${var.project_name}/${var.environment}/django/debug"
  description = "Django DEBUG setting for ${var.environment}"
  type        = "String"
  value       = var.django_debug
  overwrite   = true

  tags = local.common_tags
}

resource "aws_ssm_parameter" "django_allowed_hosts" {
  name        = "/${var.project_name}/${var.environment}/django/allowed_hosts"
  description = "Django ALLOWED_HOSTS for ${var.environment}"
  type        = "String"
  value       = var.django_allowed_hosts
  overwrite   = true

  tags = local.common_tags
}

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name

  tags = merge(local.common_tags, { Name = local.frontend_bucket_name })
}

# SSM parameter for frontend bucket name (for CI/CD)
resource "aws_ssm_parameter" "frontend_bucket_name" {
  name        = "/${var.project_name}/${var.environment}/s3/frontend_bucket_name"
  description = "Frontend S3 bucket name for ${var.environment}"
  type        = "String"
  value       = aws_s3_bucket.frontend.bucket
  overwrite   = true

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


