variable "project_name" {
  description = "Project name used for tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. staging)."
  type        = string
}

variable "tags" {
  description = "Base tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC that hosts the data layer."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for data resources."
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC to allow intra-VPC access."
  type        = string
}

variable "db_name" {
  description = "Logical database name for Aurora."
  type        = string
  default     = "habittracker"
}

variable "db_master_username" {
  description = "Master username for Aurora. Password generated automatically."
  type        = string
  default     = "dbadmin"
}

variable "frontend_bucket_name" {
  description = "Optional override for the frontend S3 bucket name."
  type        = string
  default     = ""
}

variable "aurora_min_capacity" {
  description = "Minimum ACUs for Aurora Serverless v2."
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACUs for Aurora Serverless v2."
  type        = number
  default     = 4
}

variable "django_secret_key" {
  description = "Django SECRET_KEY for the application."
  type        = string
  sensitive   = true
}

variable "django_debug" {
  description = "Django DEBUG setting (true/false as string)."
  type        = string
  default     = "False"
}

variable "django_allowed_hosts" {
  description = "Comma-separated list of allowed hosts for Django."
  type        = string
  default     = "*"
}


