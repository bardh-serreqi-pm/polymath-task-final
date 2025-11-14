# Apprentice Final Serverless Architecture

```
                                   +------------------+
                                   |   GitHub Repo    |
                                   +--------+---------+
                                            |
                         +------------------v------------------+
                         |   AWS CodePipeline (terraform)      |
                         +-----------+-----------+-------------+
                                     |           |
                       +-------------v-+     +---v-------------------+
                       | CodeBuild Plan |     | CodeBuild Apply      |
                       +------+---------+     +----------------------+ 
                              |                       |
                              |                (Same pipeline shares
                              |                 source artifact)
                              v
                     +--------+-----------------------------------+
                     |          AWS Infrastructure               |
                     +-------------------------------------------+
                     |                                           |
        +------------+-----------+                 +-------------+------------+
        | VPC (10.20.0.0/16)     |                 | CloudWatch Logs & Alarms |
        | - 2 Public Subnets     |                 | SNS Topic (alerts)       |
        | - 2 Private Subnets    |                 +-------------+------------+
        | - NAT Gateway          |                               |
        +------------+-----------+                               |
                     |                                           |
        +------------v-----------+                 +-------------v------------+
        | AWS Lambda (Django)    |<--------------->| API Gateway (HTTP API)    |
        | - Image in Amazon ECR  |                 +-------------+-------------+
        | - VPC-attached ENIs    |                               |
        +------------+-----------+                               |
                     |                                           |
                     |      +------------------------------------v----------------+
                     |      | Amazon Aurora Serverless v2 (PostgreSQL)            |
                     |      | + Secrets Manager (DB creds)                        |
                     |      | + SSM Parameter Store (Aurora/Redis endpoints, cfg) |
                     |      +------------------------------------+----------------+
                     |                                           |
                     |      +------------------------------------v----------------+
                     |      | Amazon ElastiCache Serverless (Redis)               |
                     |      +------------------------------------+----------------+
                     |                                           |
        +------------v-----------+                 +-------------v------------+
        | Amazon S3 (frontend)   |<--------------->| CloudFront Distribution   |
        | - SPA build artifacts  |                 | - OAC for S3 access       |
        +------------------------+                 +-------------+------------+
                                                                      |
                                                       +--------------v-------------+
                                                       |  End Users (Browser/App)   |
                                                       +---------------------------+
```

**Legend**
- **CodePipeline / CodeBuild**: Three pipelines (Terraform, Backend, Frontend) orchestrate builds and deployments.
- **Network Module**: Provides VPC, subnets, NAT, and routing foundation.
- **Data Module**: Hosts Aurora Serverless v2, Redis Serverless, Secrets Manager secrets, and SSM parameters.
- **Compute Module**: Deploys the Django Lambda (container image) and publishes to API Gateway.
- **Edge Module**: Serves the React frontend via S3 + CloudFront and exposes the API Gateway endpoint.
- **Observability Module**: CloudWatch metrics, alarms, dashboards, and SNS alerts.

