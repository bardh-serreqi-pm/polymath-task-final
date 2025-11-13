# ============================================================================
# SHARED OUTPUTS
# ============================================================================

output "s3_artifacts_bucket" {
  description = "S3 bucket for pipeline artifacts"
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

# Note: ECR and SNS outputs are not provided here as they come from IAC module
# Use IAC module outputs to get these values

output "github_connection_arn" {
  description = "ARN of the GitHub connection"
  value       = aws_codestarconnections_connection.github.arn
}

# ============================================================================
# TERRAFORM PIPELINE OUTPUTS
# ============================================================================

output "terraform_pipeline_name" {
  description = "Name of the Terraform CodePipeline"
  value       = aws_codepipeline.terraform.name
}

output "terraform_pipeline_arn" {
  description = "ARN of the Terraform CodePipeline"
  value       = aws_codepipeline.terraform.arn
}

output "terraform_codebuild_project_name" {
  description = "Name of the CodeBuild project for Terraform"
  value       = aws_codebuild_project.terraform.name
}

# ============================================================================
# BACKEND PIPELINE OUTPUTS
# ============================================================================

output "backend_pipeline_name" {
  description = "Name of the Backend CodePipeline"
  value       = aws_codepipeline.backend.name
}

output "backend_pipeline_arn" {
  description = "ARN of the Backend CodePipeline"
  value       = aws_codepipeline.backend.arn
}

output "backend_codebuild_project_name" {
  description = "Name of the CodeBuild project for Backend"
  value       = aws_codebuild_project.backend.name
}

# ============================================================================
# FRONTEND PIPELINE OUTPUTS
# ============================================================================

output "frontend_pipeline_name" {
  description = "Name of the Frontend CodePipeline"
  value       = aws_codepipeline.frontend.name
}

output "frontend_pipeline_arn" {
  description = "ARN of the Frontend CodePipeline"
  value       = aws_codepipeline.frontend.arn
}

output "frontend_codebuild_project_name" {
  description = "Name of the CodeBuild project for Frontend"
  value       = aws_codebuild_project.frontend.name
}
