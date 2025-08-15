variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "bitbucket_owner" {
  description = "Bitbucket owner/organization"
  type        = string
}

variable "bitbucket_repo" {
  description = "Bitbucket repository name"
  type        = string
}

variable "bitbucket_branch" {
  description = "Bitbucket branch to track"
  type        = string
}

variable "use_existing_vpc" {
  description = "Whether to use existing VPC and subnets"
  type        = bool
}

variable "existing_vpc_id" {
  description = "Existing VPC ID"
  type        = string
}

variable "existing_subnet_ids" {
  description = "Existing subnet IDs"
  type        = list(string)
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "cpu" {
  description = "CPU units for the container"
  type        = number
}

variable "memory" {
  description = "Memory (MB) for the container"
  type        = number
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "app_environment_variables" {
  description = "Environment variables for the application container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "app_secrets" {
  description = "Secret environment variables for the application container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}