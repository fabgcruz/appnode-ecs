output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.social_hub.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = module.social_hub.alb_zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.social_hub.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.social_hub.ecs_service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.social_hub.ecr_repository_url
}

output "codepipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.social_hub.codepipeline_name
}

output "codestar_connection_arn" {
  description = "ARN of the CodeStar connection (needs manual activation)"
  value       = module.social_hub.codestar_connection_arn
}

output "environment" {
  description = "Environment name"
  value       = module.social_hub.environment
}