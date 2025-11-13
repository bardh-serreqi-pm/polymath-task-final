# ============================================================================
# TERRAFORM PIPELINE
# ============================================================================

# CodeBuild Project for Terraform
resource "aws_codebuild_project" "terraform" {
  name          = "${var.project_name}-terraform-${var.environment}"
  description   = "Run Terraform plan and apply for infrastructure"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_terraform_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "hashicorp/terraform:latest"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "TF_VAR_environment"
      value = var.environment
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = var.terraform_state_bucket
    }
    environment_variable {
      name  = "TF_STATE_LOCK_TABLE"
      value = var.terraform_state_lock_table
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "ops/iac/buildspec-terraform.yml"
  }

  tags = {
    Name = "${var.project_name}-terraform-${var.environment}"
  }
}

# CodePipeline for Terraform
resource "aws_codepipeline" "terraform" {
  name     = "${var.project_name}-terraform-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_terraform_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Source Stage
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  # Terraform Plan Stage
  stage {
    name = "Plan"

    action {
      name            = "Terraform-Plan"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform.name
        EnvironmentVariables = jsonencode([
          {
            name  = "TF_ACTION"
            value = "plan"
          }
        ])
      }
    }
  }

  # Approval Stage
  stage {
    name = "Approval"

    action {
      name     = "Manual-Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Please review the Terraform plan and approve for apply."
      }
    }
  }

  # Terraform Apply Stage
  stage {
    name = "Apply"

    action {
      name            = "Terraform-Apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.terraform.name
        EnvironmentVariables = jsonencode([
          {
            name  = "TF_ACTION"
            value = "apply"
          }
        ])
      }
    }
  }

  tags = {
    Name = "${var.project_name}-terraform-pipeline-${var.environment}"
  }
}

# ============================================================================
# BACKEND (API) PIPELINE
# ============================================================================

# CodeBuild Project for Backend
resource "aws_codebuild_project" "backend" {
  name          = "${var.project_name}-backend-${var.environment}"
  description   = "Build and deploy Django API backend"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_backend_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "ECR_REPOSITORY"
      value = var.ecr_api_repository_url
    }
    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "packages/api/buildspec-backend.yml"
  }

  tags = {
    Name = "${var.project_name}-backend-${var.environment}"
  }
}

# CodeBuild Project for Backend Health Checks
# CodePipeline for Backend
resource "aws_codepipeline" "backend" {
  name     = "${var.project_name}-backend-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_backend_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Source Stage
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  # Build Stage
  stage {
    name = "Build"

    action {
      name             = "Build-Image"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.backend.name
      }
    }
  }

  # Deploy to Staging Stage
  stage {
    name = "Deploy-Staging"

    action {
      name            = "Deploy-Staging"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name != "" ? var.ecs_cluster_name : "${var.project_name}-cluster-staging"
        ServiceName = "${var.project_name}-api-service-staging"
        FileName    = "imagedefinitions.json"
      }
    }
  }

  # Approval Stage
  stage {
    name = "Approval"

    action {
      name     = "Manual-Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Please review the staging deployment and approve for production."
      }
    }
  }

  # Deploy to Production Stage
  stage {
    name = "Deploy-Production"

    action {
      name            = "Deploy-Production"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name != "" ? var.ecs_cluster_name : "${var.project_name}-cluster-production"
        ServiceName = "${var.project_name}-api-service-production"
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-backend-pipeline-${var.environment}"
  }
}

# ============================================================================
# FRONTEND (WEB) PIPELINE
# ============================================================================

# CodeBuild Project for Frontend
resource "aws_codebuild_project" "frontend" {
  name          = "${var.project_name}-frontend-${var.environment}"
  description   = "Build and deploy React frontend"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild_frontend_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "ECR_REPOSITORY"
      value = var.ecr_web_repository_url
    }
    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
    environment_variable {
      name  = "S3_BUCKET"
      value = var.frontend_s3_bucket != "" ? var.frontend_s3_bucket : "${var.project_name}-frontend-${var.environment}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "packages/web/buildspec-frontend.yml"
  }

  tags = {
    Name = "${var.project_name}-frontend-${var.environment}"
  }
}

# CodePipeline for Frontend
resource "aws_codepipeline" "frontend" {
  name     = "${var.project_name}-frontend-pipeline-${var.environment}"
  role_arn = aws_iam_role.codepipeline_frontend_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Source Stage
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  # Build Stage
  stage {
    name = "Build"

    action {
      name             = "Build-Image"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.frontend.name
      }
    }
  }

  # Deploy to Staging Stage
  stage {
    name = "Deploy-Staging"

    action {
      name            = "Deploy-Staging"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = var.frontend_s3_bucket != "" ? var.frontend_s3_bucket : "${var.project_name}-frontend-${var.environment}"
        Extract    = "true"
      }
    }
  }

  # Approval Stage
  stage {
    name = "Approval"

    action {
      name     = "Manual-Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Please review the staging deployment and approve for production."
      }
    }
  }

  # Deploy to Production Stage
  stage {
    name = "Deploy-Production"

    action {
      name            = "Deploy-Production"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = var.frontend_s3_bucket != "" ? var.frontend_s3_bucket : "${var.project_name}-frontend-production"
        Extract    = "true"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-frontend-pipeline-${var.environment}"
  }
}

