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
# EventBridge Rules for Custom Formatted Notifications
# ============================================================================
# These rules provide readable, well-formatted email notifications
# Replaces CodeStar Notifications for better email formatting

# ----------------------------------------------------------------------------
# Pipeline Success Notifications
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "terraform_success" {
  name        = "${var.project_name}-terraform-success-${var.environment}"
  description = "Notify when Terraform pipeline completes successfully"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["SUCCEEDED"]
      pipeline = ["${var.project_name}-terraform-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-terraform-success-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "terraform_success_sns" {
  rule      = aws_cloudwatch_event_rule.terraform_success.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"SUCCESS: Terraform Pipeline Completed\\n\\nPipeline: <pipeline>\\nStatus: SUCCEEDED\\nExecution ID: <execution>\\nTime: <time>\\n\\nInfrastructure changes have been successfully applied.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
  }
}

resource "aws_cloudwatch_event_rule" "backend_success" {
  name        = "${var.project_name}-backend-success-${var.environment}"
  description = "Notify when Backend pipeline completes successfully"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["SUCCEEDED"]
      pipeline = ["${var.project_name}-backend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-backend-success-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "backend_success_sns" {
  rule      = aws_cloudwatch_event_rule.backend_success.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"SUCCESS: Backend API Deployed\\n\\nPipeline: <pipeline>\\nStatus: SUCCEEDED\\nExecution ID: <execution>\\nTime: <time>\\n\\nBackend API has been successfully deployed to production.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
  }
}

resource "aws_cloudwatch_event_rule" "frontend_success" {
  name        = "${var.project_name}-frontend-success-${var.environment}"
  description = "Notify when Frontend pipeline completes successfully"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["SUCCEEDED"]
      pipeline = ["${var.project_name}-frontend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-frontend-success-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "frontend_success_sns" {
  rule      = aws_cloudwatch_event_rule.frontend_success.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"SUCCESS: Frontend Application Deployed\\n\\nPipeline: <pipeline>\\nStatus: SUCCEEDED\\nExecution ID: <execution>\\nTime: <time>\\n\\nFrontend application has been successfully deployed.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
  }
}

# ----------------------------------------------------------------------------
# Pipeline Failure Notifications
# ----------------------------------------------------------------------------

resource "aws_cloudwatch_event_rule" "terraform_failure" {
  name        = "${var.project_name}-terraform-failure-${var.environment}"
  description = "Notify when Terraform pipeline fails"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["FAILED"]
      pipeline = ["${var.project_name}-terraform-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-terraform-failure-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "terraform_failure_sns" {
  rule      = aws_cloudwatch_event_rule.terraform_failure.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"FAILURE: Terraform Pipeline Failed\\n\\nPipeline: <pipeline>\\nStatus: FAILED\\nExecution ID: <execution>\\nTime: <time>\\n\\nInfrastructure deployment has failed. Please check the logs for details.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\\nView Logs: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/executions/<execution>/timeline\""
  }
}

resource "aws_cloudwatch_event_rule" "backend_failure" {
  name        = "${var.project_name}-backend-failure-${var.environment}"
  description = "Notify when Backend pipeline fails"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["FAILED"]
      pipeline = ["${var.project_name}-backend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-backend-failure-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "backend_failure_sns" {
  rule      = aws_cloudwatch_event_rule.backend_failure.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"FAILURE: Backend API Deployment Failed\\n\\nPipeline: <pipeline>\\nStatus: FAILED\\nExecution ID: <execution>\\nTime: <time>\\n\\nBackend API deployment has failed. Please investigate immediately.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\\nView Logs: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/executions/<execution>/timeline\""
  }
}

resource "aws_cloudwatch_event_rule" "frontend_failure" {
  name        = "${var.project_name}-frontend-failure-${var.environment}"
  description = "Notify when Frontend pipeline fails"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      state    = ["FAILED"]
      pipeline = ["${var.project_name}-frontend-pipeline-${var.environment}"]
    }
  })

  tags = {
    Name        = "${var.project_name}-frontend-failure-rule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "frontend_failure_sns" {
  rule      = aws_cloudwatch_event_rule.frontend_failure.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      execution = "$.detail.execution-id"
      time      = "$.time"
    }
    input_template = "\"FAILURE: Frontend Deployment Failed\\n\\nPipeline: <pipeline>\\nStatus: FAILED\\nExecution ID: <execution>\\nTime: <time>\\n\\nFrontend deployment has failed. Please check the build logs.\\n\\nView in Console: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\\nView Logs: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/executions/<execution>/timeline\""
  }
}

# ----------------------------------------------------------------------------
# Approval Stage Notifications
# ----------------------------------------------------------------------------

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
    input_template = "\"APPROVAL REQUIRED: Terraform Infrastructure Changes\\n\\nPipeline: <pipeline>\\nStage: <stage>\\nStatus: WAITING FOR APPROVAL\\nExecution ID: <execution>\\n\\nACTION REQUIRED: Please review and approve the infrastructure changes.\\n\\nApprove/Reject: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
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
    input_template = "\"APPROVAL REQUIRED: Backend API Production Deployment\\n\\nPipeline: <pipeline>\\nStage: <stage>\\nStatus: WAITING FOR APPROVAL\\nExecution ID: <execution>\\n\\nACTION REQUIRED: Please review staging deployment and approve production release.\\n\\nApprove/Reject: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
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
    input_template = "\"APPROVAL REQUIRED: Frontend Production Deployment\\n\\nPipeline: <pipeline>\\nStage: <stage>\\nStatus: WAITING FOR APPROVAL\\nExecution ID: <execution>\\n\\nACTION REQUIRED: Please review staging deployment and approve production release.\\n\\nApprove/Reject: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/view\""
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


