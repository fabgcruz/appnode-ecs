terraform {
  required_version = ">= 1.6.0"
  
  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "social-hub/dev/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

module "social_hub" {
  source = "../.."

  # Environment configuration
  environment      = var.environment
  project_name     = var.project_name
  aws_region       = var.aws_region
  aws_account_id   = var.aws_account_id

  # Bitbucket settings
  bitbucket_owner  = var.bitbucket_owner
  bitbucket_repo   = var.bitbucket_repo
  bitbucket_branch = var.bitbucket_branch

  # Networking
  use_existing_vpc     = var.use_existing_vpc
  existing_vpc_id      = var.existing_vpc_id
  existing_subnet_ids  = var.existing_subnet_ids

  # Container settings
  container_port = var.container_port
  cpu            = var.cpu
  memory         = var.memory

  # ECR repository
  ecr_repository_name = var.ecr_repository_name

  # Application environment variables
  app_environment_variables = var.app_environment_variables
  app_secrets              = var.app_secrets

  # Tags
  tags = var.tags
}