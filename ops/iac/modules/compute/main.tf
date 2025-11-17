locals {
  common_tags = merge(
    var.tags,
    {
      Component   = "compute"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Module      = "compute"
    }
  )
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-api-ecr" })
}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda function ENIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-lambda-sg" })
}

resource "aws_security_group_rule" "lambda_to_aurora" {
  description              = "Allow Lambda to connect to Aurora"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.aurora_security_group_id
  source_security_group_id = aws_security_group.lambda.id
}

resource "aws_security_group_rule" "lambda_to_redis" {
  description              = "Allow Lambda to connect to Redis"
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = var.redis_security_group_id
  source_security_group_id = aws_security_group.lambda.id
}

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-lambda-role" })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_data_access" {
  name        = "${var.project_name}-${var.environment}-lambda-data-access"
  description = "Allow Lambda to read secrets and parameters"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.aurora_writer_endpoint_param}",
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.redis_endpoint_param}",
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_data_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_data_access.arn
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-api"
  retention_in_days = var.log_retention_in_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-${var.environment}-api"
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  role          = aws_iam_role.lambda.arn
  timeout       = 30
  memory_size   = 512
  publish       = true

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = merge(
      {
        ENVIRONMENT                  = var.environment
        PROJECT_NAME                 = var.project_name
        AWS_SECRET_NAME              = var.aurora_secret_arn
        AWS_SSM_PREFIX               = "/${var.project_name}/${var.environment}"
        AURORA_SECRET_ARN            = var.aurora_secret_arn
        AURORA_WRITER_ENDPOINT_PARAM = var.aurora_writer_endpoint_param
        REDIS_ENDPOINT_PARAM         = var.redis_endpoint_param
        DJANGO_SETTINGS_MODULE       = "Habit_Tracker.settings"
        DB_MIGRATE_ON_START          = "false"
        API_GATEWAY_STAGE            = var.environment # Stage name for middleware to strip prefix
      },
      var.lambda_environment
    )
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [aws_cloudwatch_log_group.lambda]

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-api-lambda" })
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  # For HTTP API, use the stage ARN format: arn:aws:execute-api:region:account:api-id/stage-name/*/*
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/${aws_apigatewayv2_stage.api.name}/*/*"
}

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-${var.environment}-http-api"
  protocol_type = "HTTP"

  # CORS is handled by Django middleware and CloudFront response headers
  # API Gateway CORS can cause ForbiddenException when combined with CloudFront
  # Removing CORS from API Gateway to avoid conflicts

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-http-api" })
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
  integration_method     = "POST"
  timeout_milliseconds   = 29000
}

# Explicit routes for better control and monitoring
# These routes are matched in order, so more specific routes should come first

# OPTIONS routes for CORS preflight
resource "aws_apigatewayv2_route" "options_proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "OPTIONS /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "options_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "OPTIONS /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# API endpoints
resource "aws_apigatewayv2_route" "api_proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_auth_check" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/auth/check"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_profile" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/profile"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_habits" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/habits"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_habits_proxy" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/habits/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_tasks" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/tasks"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_tasks_complete" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/tasks/complete"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "api_analysis" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /api/analysis"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Health check
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /health/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "health_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Django authentication routes
resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Login"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "register" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Register/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "register_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Register"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "logout" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Logout"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "profile" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Profile/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "profile_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Profile"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Admin routes
resource "aws_apigatewayv2_route" "admin" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /admin/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Django app routes
resource "aws_apigatewayv2_route" "habits" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "add_habit" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Add-Habit/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "add_habit_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Add-Habit"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "delete_habit" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /delete-habit/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "habit_manager" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Habit-Manager/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "habit_manager_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Habit-Manager"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "habit_infos" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Habit-Infos/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "habits_analysis" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Habits-Analysis/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "habits_analysis_root" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /Habits-Analysis"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_execution.arn
    format          = jsonencode({ requestId = "$context.requestId", status = "$context.status", path = "$context.path" })
  }

  default_route_settings {
    throttling_burst_limit = 500
    throttling_rate_limit  = 1000
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-http-stage" })
}

resource "aws_cloudwatch_log_group" "api_execution" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.api.id}"
  retention_in_days = var.log_retention_in_days
  tags              = local.common_tags
}


