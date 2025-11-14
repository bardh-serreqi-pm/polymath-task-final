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
}

resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Allow access to Aurora from application layer"
  vpc_id      = var.vpc_id

  ingress {
    description = "VPC internal access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-sg" })
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-${var.environment}-redis-sg"
  description = "Allow access to Redis from application layer"
  vpc_id      = var.vpc_id

  ingress {
    description = "VPC internal access"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  egress {
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
  name        = "${var.project_name}/${var.environment}/aurora/master"
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

resource "aws_rds_cluster" "aurora" {
  engine                       = "aurora-postgresql"
  engine_mode                  = "provisioned"
  engine_version               = "15.3"
  database_name                = var.db_name
  master_username              = var.db_master_username
  master_password              = random_password.aurora_master.result
  db_subnet_group_name         = aws_db_subnet_group.aurora.name
  vpc_security_group_ids       = [aws_security_group.aurora.id]
  storage_encrypted            = true
  deletion_protection          = false
  backup_retention_period      = 3
  preferred_backup_window      = "03:00-05:00"
  preferred_maintenance_window = "sun:05:00-sun:07:00"
  copy_tags_to_snapshot        = true
  allow_major_version_upgrade  = false
  apply_immediately            = true
  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-aurora-cluster" })
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
  subnet_ids           = var.private_subnet_ids
  security_group_ids   = [aws_security_group.redis.id]

  cache_usage_limits {
    data_storage {
      unit    = "GB"
      minimum = 1
      maximum = 10
    }

  }

  snapshot_retention_limit = 1

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-redis" })
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

resource "aws_s3_bucket" "frontend" {
  bucket = local.frontend_bucket_name

  tags = merge(local.common_tags, { Name = local.frontend_bucket_name })
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


