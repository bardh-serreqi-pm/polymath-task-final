data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  state_bucket_arn         = data.aws_s3_bucket.terraform_state.arn
  state_bucket_objects_arn = "${data.aws_s3_bucket.terraform_state.arn}/*"
  lock_table_arn           = "arn:${local.partition}:dynamodb:${local.region}:${local.account_id}:table/${var.terraform_state_lock_table}"

  frontend_bucket_objects_arn = "${var.frontend_bucket_arn}/*"
  lambda_log_group_arn        = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${var.lambda_log_group_name}:*"
  api_gateway_log_group_arn   = "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:${var.api_gateway_log_group_name}:*"
  api_gateway_arn_base        = "arn:${local.partition}:apigateway:${local.region}::/apis/${var.api_gateway_id}"
  api_gateway_child_arn       = "${local.api_gateway_arn_base}/*"
  redis_cluster_arn           = var.redis_cluster_arn
  cloudfront_distribution_arn = var.cloudfront_distribution_arn
  ssm_parameter_arn_prefix    = "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter${var.ssm_parameter_prefix}*"

  iam_user_arn             = "arn:${local.partition}:iam::${local.account_id}:user/${var.iam_user_name}"
  iam_role_pattern         = "arn:${local.partition}:iam::${local.account_id}:role/${var.project_name}-${var.environment}-*"
  iam_policy_pattern       = "arn:${local.partition}:iam::${local.account_id}:policy/${var.project_name}-${var.environment}-*"
  rds_instance_arn         = var.aurora_instance_arn
  backup_primary_vault_arn = var.backup_vault_primary_arn
  backup_dr_vault_arn      = var.backup_vault_dr_arn

  tags = merge(
    var.tags,
    {
      Component   = "iam"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Project     = var.project_name
    }
  )
}

data "aws_s3_bucket" "terraform_state" {
  bucket = var.terraform_state_bucket
}

data "aws_iam_policy_document" "project_operator" {
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      local.state_bucket_objects_arn
    ]
  }

  statement {
    sid    = "TerraformStateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      local.state_bucket_arn
    ]
  }

  statement {
    sid    = "TerraformLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable"
    ]
    resources = [local.lock_table_arn]
  }

  statement {
    sid    = "FrontendBucketDeployment"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.frontend_bucket_arn,
      local.frontend_bucket_objects_arn
    ]
  }

  statement {
    sid    = "NetworkingResources"
    effect = "Allow"
    actions = [
      "ec2:*"
    ]
    resources = [
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:vpc/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:subnet/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:route-table/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:internet-gateway/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:natgateway/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:security-group/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:network-acl/*",
      "arn:${local.partition}:ec2:${local.region}:${local.account_id}:eip-allocation/*"
    ]
  }

  statement {
    sid    = "IAMRoleManagement"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]
    resources = [
      local.iam_role_pattern
    ]
    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = [
        "lambda.amazonaws.com",
        "apigateway.amazonaws.com",
        "backup.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "IAMPolicyManagement"
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]
    resources = [
      local.iam_policy_pattern
    ]
  }

  statement {
    sid    = "ECRManagement"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "LambdaManagement"
    effect = "Allow"
    actions = [
      "lambda:*"
    ]
    resources = [var.lambda_function_arn]
  }

  statement {
    sid    = "APIGatewayManagement"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE"
    ]
    resources = [
      local.api_gateway_arn_base,
      local.api_gateway_child_arn
    ]
  }

  statement {
    sid    = "RDSManagement"
    effect = "Allow"
    actions = [
      "rds:*"
    ]
    resources = [
      var.aurora_cluster_arn,
      local.rds_instance_arn
    ]
  }

  statement {
    sid    = "ElastiCacheManagement"
    effect = "Allow"
    actions = [
      "elasticache:*"
    ]
    resources = [local.redis_cluster_arn]
  }

  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]
    resources = [var.aurora_secret_arn]
  }

  statement {
    sid    = "SSMParameterManagement"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:PutParameter",
      "ssm:DeleteParameter",
      "ssm:AddTagsToResource",
      "ssm:RemoveTagsFromResource"
    ]
    resources = [local.ssm_parameter_arn_prefix]
  }

  statement {
    sid    = "CloudFrontManagement"
    effect = "Allow"
    actions = [
      "cloudfront:GetDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:GetFunction",
      "cloudfront:CreateFunction",
      "cloudfront:UpdateFunction",
      "cloudfront:DeleteFunction",
      "cloudfront:PublishFunction",
      "cloudfront:ListFunctions",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:CreateResponseHeadersPolicy",
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
      "cloudfront:ListResponseHeadersPolicies",
      "cloudfront:GetOriginRequestPolicy",
      "cloudfront:CreateOriginRequestPolicy",
      "cloudfront:UpdateOriginRequestPolicy",
      "cloudfront:DeleteOriginRequestPolicy",
      "cloudfront:ListOriginRequestPolicies",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:ListOriginAccessControls"
    ]
    resources = [
      local.cloudfront_distribution_arn,
      "arn:${local.partition}:cloudfront::${local.account_id}:function/${var.project_name}-${var.environment}-*",
      "arn:${local.partition}:cloudfront::${local.account_id}:response-headers-policy/${var.project_name}-${var.environment}-*",
      "arn:${local.partition}:cloudfront::${local.account_id}:origin-request-policy/${var.project_name}-${var.environment}-*",
      "arn:${local.partition}:cloudfront::${local.account_id}:origin-access-control/${var.project_name}-${var.environment}-*"
    ]
  }

  statement {
    sid    = "Route53Management"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ACMManagement"
    effect = "Allow"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WAFManagement"
    effect = "Allow"
    actions = [
      "wafv2:CreateWebACL",
      "wafv2:DeleteWebACL",
      "wafv2:UpdateWebACL",
      "wafv2:GetWebACL",
      "wafv2:ListWebACLs",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "wafv2:TagResource",
      "wafv2:UntagResource"
    ]
    resources = [var.waf_web_acl_arn]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DeleteLogGroup",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
      "logs:PutSubscriptionFilter"
    ]
    resources = [
      local.lambda_log_group_arn,
      local.api_gateway_log_group_arn
    ]
  }

  statement {
    sid    = "CloudWatchDashboardsAndAlarms"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "cloudwatch:PutDashboard",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SNSAccess"
    effect = "Allow"
    actions = [
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:Publish",
      "sns:ListSubscriptionsByTopic"
    ]
    resources = [var.sns_topic_arn]
  }

  statement {
    sid    = "BackupManagement"
    effect = "Allow"
    actions = [
      "backup:*",
      "backup-storage:*"
    ]
    resources = [
      local.backup_primary_vault_arn,
      local.backup_dr_vault_arn,
      "arn:${local.partition}:backup:${local.region}:${local.account_id}:backup-plan:${var.project_name}-${var.environment}-aurora-dr",
      "arn:${local.partition}:backup:${local.region}:${local.account_id}:backup-selection:${var.project_name}-${var.environment}-aurora-selection"
    ]
  }
}

resource "aws_iam_role" "project_operator" {
  name = "${var.project_name}-${var.environment}-operator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = local.iam_user_arn
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.tags, {
    Name = "${var.project_name}-${var.environment}-operator-role"
  })
}

resource "aws_iam_role_policy" "project_operator" {
  name   = "${var.project_name}-${var.environment}-operator-policy"
  role   = aws_iam_role.project_operator.id
  policy = data.aws_iam_policy_document.project_operator.json
}

data "aws_iam_policy_document" "assume_operator_role" {
  statement {
    sid     = "AllowAssumeOperatorRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      aws_iam_role.project_operator.arn
    ]
  }
}

resource "aws_iam_policy" "assume_operator_role" {
  name   = "${var.project_name}-${var.environment}-assume-operator-role"
  policy = data.aws_iam_policy_document.assume_operator_role.json
}

resource "aws_iam_user_policy_attachment" "apprentice_user_assume_role" {
  user       = var.iam_user_name
  policy_arn = aws_iam_policy.assume_operator_role.arn
}


