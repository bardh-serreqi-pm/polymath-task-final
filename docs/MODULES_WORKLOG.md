# Terraform Module Worklog

This document captures the infrastructure work completed so far while migrating the project to the serverless (Option B) architecture. Each section lists the newly created or refactored module, the resources it provisions, key configuration decisions, and relevant outputs/variables that other stacks consume.

---

## 1. Root `ops/iac` Composition

- Added `ops/iac/main.tf` to orchestrate all submodules in a single environment-aware stack.
- Wired shared variables (`project_name`, `environment`, tagging, networking CIDRs, Lambda image URI, etc.) into the module calls.
- Exposed consolidated outputs (VPC IDs, Lambda identifiers, Aurora secret ARN, CloudFront domain, SNS topic, dashboard name) for CI/CD consumption.
- Expanded `variables.tf` with serverless-specific inputs (Lambda image URI, optional frontend bucket override, Aurora scaling bounds) and refreshed `terraform.tfvars.example`.

---

## 2. Network Module (`ops/iac/modules/network`)

**Resources**
- `aws_vpc` with DNS support/hostnames for Lambda + Aurora integrations.
- Public and private subnets (AZ spread driven by availability-zone data source).
- Internet Gateway, NAT Gateway (EIP configured with `domain = "vpc"`), route tables, and associations per subnet tier.

**Key decisions**
- CIDR blocks default to `10.20.0.0/16` with two public and two private /24 subnets; values remain overrideable via root variables.
- Common tagging enforced through `local.common_tags` for traceability.

**Outputs**
- VPC ID, public/private subnet ID lists, and the VPC CIDR block for downstream modules (data + compute security rules).

---

## 3. Data Module (`ops/iac/modules/data`)

**Resources**
- Aurora Serverless v2 (PostgreSQL) cluster + instance with generated master password (stored in Secrets Manager).
- Secrets Manager secret version now records hostname post-cluster creation (depends_on ensures endpoint availability).
- Serverless ElastiCache Redis cache (security group + subnet group) with supported `data_storage` usage limit.
- SSM Parameter Store entries for Aurora writer/reader endpoints and Redis endpoint for runtime discovery.
- Dedicated security groups for Aurora and Redis with VPC CIDR ingress, plus DB subnet group.

**Key decisions**
- Random password resource updated to use the non-deprecated `numeric` flag.
- ElastiCache configuration trimmed to supported limits only (removed deprecated `ecpu` block).
- Secrets tagged and named under `${project_name}/${environment}` namespace for multi-env compatibility.

**Outputs**
- Aurora cluster ARN, secret ARN, writer/reader endpoints, Redis endpoint, security group IDs, and SSM parameter names for compute module wiring.

---

## 4. Compute Module (`ops/iac/modules/compute`)

**Resources**
- ECR repository for the Django Lambda container image.
- Lambda security group allowing egress plus ingress rules on Aurora/Redis SGs to permit RDS + cache connectivity.
- IAM role with VPC access, CloudWatch logging, and scoped Secrets Manager/SSM permissions.
- Lambda function defined as container image (environment variables expose secret/parameter references).
- API Gateway HTTP API with Lambda proxy integration, default route, stage logging, and access log group.
- CloudWatch log groups for Lambda and API execution; Lambda permission for API Gateway invocation.

**Key decisions**
- Lambda environment merges base variables with override map supplied via root module (`lambda_environment`).
- API Gateway stage configured with throttling defaults and access logging JSON format.

**Outputs**
- Lambda identifiers, security group ID, ECR repository URL, API Gateway invoke URL, execute-domain (for CloudFront origin), API ID, and stage name.

---

## 5. Edge Module (`ops/iac/modules/edge`)

**Resources**
- Private S3 bucket for static frontend assets with versioning and public-access block.
- CloudFront Origin Access Control and distribution with dual origins (S3 + API Gateway), caching rules, and managed policies.
- Baseline CloudFront WAF ACL using AWS managed rule group.
- Bucket policy granting CloudFront access.

**Key decisions**
- CloudFront uses `/api/*` path behavior to route to API Gateway; default behavior serves SPA from S3.
- Optional `frontend_bucket_name` override allows pre-existing bucket usage.
- Removed logging block to keep configuration concise pending logging strategy alignment.

**Outputs**
- Frontend bucket name, CloudFront distribution domain and ID, WAF ACL ARN.

---

## 6. Observability Module (`ops/iac/modules/observability`)

**Resources**
- SNS topic for operational alerts (reused by pipelines for notifications).
- CloudWatch alarms for API Gateway 5XX error rate and latency.
- CloudWatch dashboard summarizing key API metrics.

**Key decisions**
- Alarm metrics use metric math to calculate 5xx %; both alarms publish to SNS for OK + ALARM transitions.

**Outputs**
- SNS topic ARN and dashboard name for integration within CI/CD and runbooks.

---

## 7. CI/CD Module Touchpoints (High-Level)

While the request focuses on Terraform modules, the CI/CD stack was updated to align with the new module outputs:

- Pipelines now consume `api_ecr_repository_url`, `frontend_bucket_name`, `cloudfront_distribution_id`, `api_gateway_url`, and `alerts_sns_topic_arn` from the IAC outputs.
- Backend pipeline writes a `lambda-image.json` artifact consumed by the Terraform CodeBuild project to update the Lambda image via apply stages.
- Frontend buildspec was reworked to run the React build, sync to S3, and create a CloudFront invalidation (ECR usage removed).
- IAM policies adjusted to drop deprecated permissions, add CloudFront invalidation rights, and rely on the new bucket variable names.

---

## 8. Pending / Next Steps

- Update Django container packaging for Lambda runtime (handler entrypoint, dependency slimming).
- Extend application code to pull config from Secrets Manager + SSM at startup.
- Flesh out production `terraform.tfvars` once resource names and AWS account IDs are finalized.
- Add Route53/ACM integration once domain wiring requirements are known.

---

_Last updated: 2025-11-13_
