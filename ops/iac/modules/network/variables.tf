variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. staging, production)."
  type        = string
}

variable "tags" {
  description = "Base tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDRs to use for public subnets."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDRs to use for private subnets."
  type        = list(string)
  default     = ["10.20.16.0/24", "10.20.17.0/24"]
}


