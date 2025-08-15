variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "social-hub"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

# Bitbucket settings
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
  default     = "main"
}

# Networking options
variable "use_existing_vpc" {
  description = "Whether to use existing VPC and subnets"
  type        = bool
  default     = false
}

variable "existing_vpc_id" {
  description = "Existing VPC ID (when use_existing_vpc is true)"
  type        = string
  default     = ""
}

variable "existing_subnet_ids" {
  description = "Existing subnet IDs (when use_existing_vpc is true)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "VPC CIDR block (when creating new VPC)"
  type        = string
  default     = "10.90.0.0/16"
}

variable "public_subnet_az1_cidr" {
  description = "Public subnet AZ1 CIDR (when creating new VPC)"
  type        = string
  default     = "10.90.1.0/24"
}

variable "public_subnet_az2_cidr" {
  description = "Public subnet AZ2 CIDR (when creating new VPC)"
  type        = string
  default     = "10.90.2.0/24"
}

# Container settings
variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "cpu" {
  description = "CPU units for the container"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory (MB) for the container"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Application environment variables
variable "app_environment_variables" {
  description = "Environment variables for the application container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Sensitive environment variables (from AWS Secrets Manager or Parameter Store)
variable "app_secrets" {
  description = "Secret environment variables for the application container (references to Secrets Manager or Parameter Store)"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}