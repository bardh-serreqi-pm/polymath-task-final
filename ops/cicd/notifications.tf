# ============================================================================
# CI/CD PIPELINE NOTIFICATIONS
# ============================================================================
# SNS topic and notifications for pipeline events (approval required, completion)

# ============================================================================
# SNS Topic for Pipeline Notifications
# ============================================================================
# Note: AWS CodeStar Notifications service-linked role already exists in the account
# (AWSServiceRoleForCodeStarNotifications) and is used automatically

resource "aws_sns_topic" "pipeline_notifications" {
  name         = "${var.project_name}-${var.environment}-pipeline-notifications"
  display_name = "CI/CD Pipeline Notifications - ${var.project_name}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-pipeline-notifications"
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "CI/CD Pipeline Notifications"
  }
}

# Email Subscription for Pipeline Notifications
resource "aws_sns_topic_subscription" "pipeline_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pipeline_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================================================
# CodeStar Notifications for Terraform Pipeline
# ============================================================================

resource "aws_codestarnotifications_notification_rule" "terraform_pipeline" {
  name        = "${var.project_name}-terraform-pipeline-notifications-${var.environment}"
  detail_type = "FULL"
  resource    = aws_codepipeline.terraform.arn

  # Events to notify on
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded", # Pipeline completed successfully
    "codepipeline-pipeline-pipeline-execution-failed",    # Pipeline failed
  ]

  target {
    address = aws_sns_topic.pipeline_notifications.arn
    type    = "SNS"
  }

  tags = {
    Name        = "${var.project_name}-terraform-notifications"
    Environment = var.environment
    Pipeline    = "Terraform"
  }
}

# ============================================================================
# CodeStar Notifications for Backend Pipeline
# ============================================================================

resource "aws_codestarnotifications_notification_rule" "backend_pipeline" {
  name        = "${var.project_name}-backend-pipeline-notifications-${var.environment}"
  detail_type = "FULL"
  resource    = aws_codepipeline.backend.arn

  # Events to notify on
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded", # Pipeline completed successfully
    "codepipeline-pipeline-pipeline-execution-failed",    # Pipeline failed
  ]

  target {
    address = aws_sns_topic.pipeline_notifications.arn
    type    = "SNS"
  }

  tags = {
    Name        = "${var.project_name}-backend-notifications"
    Environment = var.environment
    Pipeline    = "Backend"
  }
}

# ============================================================================
# CodeStar Notifications for Frontend Pipeline
# ============================================================================

resource "aws_codestarnotifications_notification_rule" "frontend_pipeline" {
  name        = "${var.project_name}-frontend-pipeline-notifications-${var.environment}"
  detail_type = "FULL"
  resource    = aws_codepipeline.frontend.arn

  # Events to notify on
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-succeeded", # Pipeline completed successfully
    "codepipeline-pipeline-pipeline-execution-failed",    # Pipeline failed
  ]

  target {
    address = aws_sns_topic.pipeline_notifications.arn
    type    = "SNS"
  }

  tags = {
    Name        = "${var.project_name}-frontend-notifications"
    Environment = var.environment
    Pipeline    = "Frontend"
  }
}

# ============================================================================
# EventBridge Rules for Approval Stage Notifications
# ============================================================================
# These rules specifically watch for Approval stage starts (not all stages)

resource "aws_cloudwatch_event_rule" "terraform_approval" {
  name        = "${var.project_name}-terraform-approval-${var.environment}"
  description = "Notify when Terraform pipeline reaches approval stage"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Stage Execution State Change"]
    detail = {
      state    = ["STARTED"]
      stage    = ["Approval"]
      pipeline = ["${var.project_name}-terraform-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-terraform-approval-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "terraform_approval_sns" {
  rule      = aws_cloudwatch_event_rule.terraform_approval.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      stage     = "$.detail.stage"
      execution = "$.detail.execution-id"
    }
    input_template = "\"⚠️ APPROVAL REQUIRED: Pipeline '<pipeline>' has reached the '<stage>' stage and requires manual approval. Execution ID: <execution>\""
  }
}

resource "aws_cloudwatch_event_rule" "backend_approval" {
  name        = "${var.project_name}-backend-approval-${var.environment}"
  description = "Notify when Backend pipeline reaches approval stage"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Stage Execution State Change"]
    detail = {
      state    = ["STARTED"]
      stage    = ["Approval"]
      pipeline = ["${var.project_name}-backend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-backend-approval-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "backend_approval_sns" {
  rule      = aws_cloudwatch_event_rule.backend_approval.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      stage     = "$.detail.stage"
      execution = "$.detail.execution-id"
    }
    input_template = "\"⚠️ APPROVAL REQUIRED: Pipeline '<pipeline>' has reached the '<stage>' stage and requires manual approval. Execution ID: <execution>\""
  }
}

resource "aws_cloudwatch_event_rule" "frontend_approval" {
  name        = "${var.project_name}-frontend-approval-${var.environment}"
  description = "Notify when Frontend pipeline reaches approval stage"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Stage Execution State Change"]
    detail = {
      state    = ["STARTED"]
      stage    = ["Approval"]
      pipeline = ["${var.project_name}-frontend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-frontend-approval-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "frontend_approval_sns" {
  rule      = aws_cloudwatch_event_rule.frontend_approval.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      stage     = "$.detail.stage"
      execution = "$.detail.execution-id"
    }
    input_template = "\"⚠️ APPROVAL REQUIRED: Pipeline '<pipeline>' has reached the '<stage>' stage and requires manual approval. Execution ID: <execution>\""
  }
}

# ============================================================================
# SNS Topic Policy for CodeStar Notifications
# ============================================================================

resource "aws_sns_topic_policy" "pipeline_notifications" {
  arn = aws_sns_topic.pipeline_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeStarNotifications"
        Effect = "Allow"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
      },
      {
        Sid    = "AllowEventBridge"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
      },
      {
        Sid    = "AllowAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "pipeline_notifications_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.arn
}

output "pipeline_notifications_topic_name" {
  description = "Name of the SNS topic for pipeline notifications"
  value       = aws_sns_topic.pipeline_notifications.name
}

