\# Apprentice Final Project

\## AWS Infrastructure Implementation for a Multi-Tier Application

\-\--

\### 1. Objective

Design, implement, and document a complete AWS infrastructure for a
sample multi-tier web application that runs both locally (in containers)
and in AWS.

\- Select a simple open-source web app that includes:

\- Frontend (Web UI)

\- Backend (API)

\- Relational Database (DB)

\- Caching Layer (CacheDB)

\- Run the application locally using Docker Compose (4 containers total)

\- Provision all necessary AWS infrastructure via Terraform

\- Implement monitoring, logging, alerting (email), and CI/CD
automation\*\*

\- Ensure all configurations are stored via environment variables (no
hard-coding)

\- Provide a complete documentation package aligned with the AWS
Well-Architected Framework

\-\--

\### 2. Technical Requirements

\#### 2.1 Local Environment

\*\*Components (Docker Compose):\*\*

1\. \`web\` -- frontend (React, Flask, or similar)

2\. \`api\` -- backend API (Node.js, FastAPI, etc.)

3\. \`db\` -- relational database (PostgreSQL / MySQL)

4\. \`cache\` -- in-memory store (Redis or Memcached)

\*\*Local Setup Rules:\*\*

\- All configuration comes from \`.env\`

\- Provide \`.env.example\` with placeholder values

\- Expose health checks for API and web

\- Use a local network for inter-container communication

\- Logs visible via \`docker logs\`

**3. AWS Cloud Architecture**

You must choose **one of the following architectures**:

**Option A -- ECS Fargate Architecture**

-   ECS Cluster running web and api containers as separate services

-   RDS (PostgreSQL/MySQL)

-   Elasticache (Redis)

-   ALB (Application Load Balancer) for routing to the API

-   CloudFront distribution in front of the ALB

-   AWS WAF for CloudFront

-   Route53 custom DNS record (e.g., project.\<yourname\>.com)

-   Logs to CloudWatch, metrics to CloudWatch dashboards

**Option B -- Serverless Architecture**

-   API Gateway → Lambda (container image) for the API

-   CloudFront → S3 (static web hosting) for frontend

-   DynamoDB or Aurora Serverless for database

-   Elasticache (Redis Serverless) for caching

-   WAF for CloudFront

-   Route53 custom DNS record

-   CloudWatch logs, metrics, and alarms

**4. Infrastructure as Code (Terraform)**

**Requirements:**

-   Use Terraform modules for:

    -   network -- VPC, subnets, NAT, IGW, routing

    -   compute -- ECS services or Lambda

    -   data -- RDS / DynamoDB + Elasticache

    -   edge -- CloudFront, WAF, Route53, ACM

    -   observability -- CloudWatch dashboards, alarms, logs

    -   iam -- least-privilege IAM roles

-   TF remote state backend (S3 + DynamoDB table)

-   All variables externalized (variables.tf and \*.tfvars)

-   No static credentials or IDs hard-coded

**Tag all AWS Services:**

tags = {

Environment = \"staging\"

Project = \"ApprenticeFinal\"

Owner = \"\<yourname\>\"

}

**5. Monitoring, Logging, and Alerting**

**Logging**

-   All application logs to CloudWatch Logs

-   ECS/Lambda configured to send logs to specific log groups
    (/aws/app/\<env\>)

**Metrics**

-   Collect from:

    -   ALB / API Gateway

    -   ECS / Lambda

    -   RDS / DynamoDB

    -   Redis / Elasticache

-   Create at least one **CloudWatch Dashboard** showing:

    -   Request counts (2xx / 4xx / 5xx)

    -   Latency

    -   DB connections / throttles

    -   Cache hit ratio

**Alerting**

-   At least **two CloudWatch alarms**:

    -   High 5xx error rate (\>5% for 5 min)

    -   High latency or CPU usage

-   Alarms notify an **SNS topic**

-   SNS topic must send **email alerts**

-   Document alert subscription and test steps

**6. CI/CD Pipeline**

Use AWS CodePipeline or GitHub Actions.

**Pipeline Stages:**

1.  **Build**

    -   Build container images (if applicable)

2.  **Deploy to Staging**

    -   Terraform plan & apply for staging environment

    -   Update ECR and ECS service / Lambda configuration

3.  **Test**

    -   Invoke /health endpoint of staging app

4.  **Approval Step**

    -   Manual approval

5.  **Deploy to Production**

    -   Terraform apply for production environment

    -   Post-deployment validation (e.g., curl /health)

6.  **Notify**

    -   Send notification (Slack or email via SNS)

**7. Cost Estimation**

Prepare an **AWS Pricing Calculator** estimate including:

-   VPC + NAT gateways

-   ECS or Lambda

-   RDS / DynamoDB

-   Elasticache (Redis)

-   CloudFront + WAF

-   CloudWatch Logs and Metrics

Include:

-   Monthly cost per environment (staging, production)

-   Cost summary table

-   Link to the AWS Calculator and estimate in docs/COST.md

**\
**

**8. Documentation Deliverables**

Organize documentation in docs/:

  ------------------------------------------------------------------------
  **File**              **Purpose**
  --------------------- --------------------------------------------------
  README.md             Overview, setup instructions, how to run locally
                        and deploy

  ARCHITECTURE.md       Logical and physical diagrams + AWS components
                        explanation

  RUNBOOK.md            Operational guide (deploy, rollback, recover,
                        scale, test alerts)

  WELL-ARCHITECTED.md   Mapping to all 6 pillars with evidence and
                        rationale

  COST.md               AWS Pricing Calculator breakdown and analysis
  ------------------------------------------------------------------------

**9. Repository Structure**

-   Follow the file structure used during program.

**10. Design Reasoning (Architecture Rationale)**
    Document and justify why you chose ECS Fargate or Serverless. Include a short trade-off table comparing scalability, cost, security, and complexity.
    The reasoning must be logical and consistent with the workload type.

**11. Evaluation Criteria**

  ------------------------------------------------------------------------
  **Category**         **Description**                      **Weight**
  -------------------- ------------------------------------ --------------
  Local Environment    4-container setup, clean .env        10%

  Infrastructure as    Terraform modular design, no         25%
  Code                 hard-coding                          

  Security & IAM       Least privilege, Secrets Manager /   15%
                       SSM, WAF                             

  Monitoring &         Logs, dashboards, email alerts       15%
  Alerting                                                  

  CI/CD                Working pipeline with approval step  10%

  Documentation        Clear README, Runbook, WA mapping    10%

  Cost Analysis        Realistic AWS Calculator estimate    5%

  Design Reasoning     Trade-off table                      10%

      
  ------------------------------------------------------------------------

**12. Submission Checklist**

-   App runs locally with docker-compose up

-   Terraform validated and modular

-   AWS environment deployed successfully

-   CI/CD pipeline tested end-to-end

-   Alarms trigger and send email notifications

-   All docs complete and linked in README

-   Pricing estimate attached in docs/COST.md

-   Design Reasoning, trade-off table

**13. Optional Enhancements (Bonus Points)**

-   Enable **HTTPS** using ACM certificate on CloudFront 5%

-   Add **multi-region support** (dev, staging, prod) 5%
