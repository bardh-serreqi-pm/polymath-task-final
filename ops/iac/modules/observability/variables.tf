variable "project_name" {
  description = "Project name for tagging."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "tags" {
  description = "Base tags to apply."
  type        = map(string)
  default     = {}
}

variable "api_gateway_id" {
  description = "ID of the API Gateway for monitoring."
  type        = string
}

variable "api_gateway_stage_name" {
  description = "Stage name for API Gateway."
  type        = string
}


