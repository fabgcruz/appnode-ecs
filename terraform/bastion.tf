# Bastion Host Access Configuration
# This assumes there's already a bastion host in the VPC
# We'll create security group rules to allow access from bastion to our resources

data "aws_security_groups" "bastion" {
  count = var.use_existing_vpc ? 1 : 0
  
  filter {
    name   = "group-name"
    values = ["*bastion*", "*jump*", "*jumpbox*"]
  }
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# Security group rule to allow bastion access to ECS tasks
resource "aws_security_group_rule" "ecs_from_bastion" {
  count                    = var.use_existing_vpc && length(data.aws_security_groups.bastion[0].ids) > 0 ? 1 : 0
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_groups.bastion[0].ids[0]
  security_group_id        = aws_security_group.ecs_service.id
  description              = "Allow bastion access to ECS tasks"
}

# Security group rule to allow bastion access to Redis
resource "aws_security_group_rule" "redis_from_bastion" {
  count                    = var.use_existing_vpc && length(data.aws_security_groups.bastion[0].ids) > 0 ? 1 : 0
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_groups.bastion[0].ids[0]
  security_group_id        = aws_security_group.redis.id
  description              = "Allow bastion access to Redis"
}

# Create IAM role for ECS exec (if not exists)
resource "aws_iam_role" "ecs_exec_role" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.default_tags
}

# Policy for ECS exec
resource "aws_iam_role_policy" "ecs_exec_policy" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-ecs-exec-policy"
  role  = aws_iam_role.ecs_exec_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Output bastion information
output "bastion_security_groups" {
  description = "Bastion security groups found"
  value       = var.use_existing_vpc && length(data.aws_security_groups.bastion) > 0 ? data.aws_security_groups.bastion[0].ids : []
}

output "ecs_exec_enabled" {
  description = "Whether ECS exec is enabled for secure access"
  value       = var.environment == "prod"
}