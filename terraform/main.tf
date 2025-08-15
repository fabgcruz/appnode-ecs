terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  name_prefix     = "${var.environment}-${var.project_name}"
  alb_name        = "${local.name_prefix}-alb"
  tg_name         = "${local.name_prefix}-tg"
  cluster_name    = "${local.name_prefix}-cluster"
  service_name    = "${local.name_prefix}-service"
  task_family     = "${local.name_prefix}-task"
  artifact_bucket = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
  
  default_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Name        = "${local.name_prefix}"
  })
}

data "aws_caller_identity" "current" {}

# Get ECR repository (assume it exists)
data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# Data sources for existing VPC resources (when use_existing_vpc is true)
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_subnets" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  filter {
    name   = "subnet-id"
    values = var.existing_subnet_ids
  }
}

data "aws_subnet" "existing" {
  count = var.use_existing_vpc ? length(var.existing_subnet_ids) : 0
  id    = var.existing_subnet_ids[count.index]
}

# Get availability zones for new VPC creation
data "aws_availability_zones" "available" {
  count = var.use_existing_vpc ? 0 : 1
  state = "available"
}

# --------------
# Networking - Create new VPC if needed
# --------------
resource "aws_vpc" "this" {
  count                = var.use_existing_vpc ? 0 : 1
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.this[0].id
  
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public_az1" {
  count                   = var.use_existing_vpc ? 0 : 1
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnet_az1_cidr
  availability_zone       = data.aws_availability_zones.available[0].names[0]
  map_public_ip_on_launch = true
  
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-public-a"
  })
}

resource "aws_subnet" "public_az2" {
  count                   = var.use_existing_vpc ? 0 : 1
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnet_az2_cidr
  availability_zone       = data.aws_availability_zones.available[0].names[1]
  map_public_ip_on_launch = true
  
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-public-b"
  })
}

resource "aws_route_table" "public" {
  count  = var.use_existing_vpc ? 0 : 1
  vpc_id = aws_vpc.this[0].id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[0].id
  }
  
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "a" {
  count          = var.use_existing_vpc ? 0 : 1
  subnet_id      = aws_subnet.public_az1[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "b" {
  count          = var.use_existing_vpc ? 0 : 1
  subnet_id      = aws_subnet.public_az2[0].id
  route_table_id = aws_route_table.public[0].id
}

# Local values for VPC and subnets (existing or new)
locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : aws_vpc.this[0].id
  subnet_ids = var.use_existing_vpc ? var.existing_subnet_ids : [
    aws_subnet.public_az1[0].id,
    aws_subnet.public_az2[0].id
  ]
}

# --------------
# Security Groups
# --------------
resource "aws_security_group" "alb" {
  name        = "${local.alb_name}-sg"
  description = "ALB Security Group for ${local.name_prefix}"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.alb_name}-sg"
  })
}

resource "aws_security_group" "ecs_service" {
  name        = "${local.service_name}-sg"
  description = "ECS Service Security Group for ${local.name_prefix}"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow ALB to connect to container port"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.service_name}-sg"
  })
}

# --------------
# ALB + Target Group + Listener
# --------------
resource "aws_lb" "this" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.subnet_ids

  enable_deletion_protection = false

  tags = merge(local.default_tags, {
    Name = local.alb_name
  })
}

resource "aws_lb_target_group" "this" {
  name        = local.tg_name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 5
  }

  tags = merge(local.default_tags, {
    Name = local.tg_name
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.default_tags, {
    Name = "${local.alb_name}-http-listener"
  })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "arn:aws:acm:us-east-1:600035690104:certificate/0ab1481a-f703-4ec4-955d-aa4ba5d7d6f3"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(local.default_tags, {
    Name = "${local.alb_name}-https-listener"
  })
}

# --------------
# ECS Cluster, Task Definition, Service
# --------------
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.default_tags, {
    Name = local.cluster_name
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.task_family}"
  retention_in_days = 14

  tags = merge(local.default_tags, {
    Name = "/ecs/${local.task_family}"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for accessing secrets
resource "aws_iam_role_policy" "ecs_task_exec_secrets" {
  name = "${local.name_prefix}-ecs-task-exec-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.environment}/social-hub/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.environment}/social-hub/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.${var.aws_region}.amazonaws.com",
              "ssm.${var.aws_region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

# IAM Role for ECS Task (application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = local.task_family
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${data.aws_ecr_repository.app.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      
      environment = concat([
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_replication_group.redis.primary_endpoint_address
        },
        {
          name  = "REDIS_PORT"
          value = tostring(aws_elasticache_replication_group.redis.port)
        },
        {
          name  = "AYRSHARE_API_URL"
          value = "https://app.ayrshare.com/api"
        },
        {
          name  = "SWAGGER_VERSION"
          value = var.environment == "prod" ? "1.0.0-prod" : "1.0.0-dev"
        },
        {
          name  = "AYRSHARE_SECRET_NAME"
          value = "social-hub/ayrshare-private-key"
        },
        {
          name  = "PADDLE_BASE_URL"
          value = var.environment == "prod" ? "https://api.paddle.com" : "https://fau9i1usal.execute-api.us-east-1.amazonaws.com/teste"
        },
        {
          name  = "ENABLE_SWAGGER"
          value = var.environment == "prod" ? "false" : "true"
        },
        {
          name  = "CORS_ORIGIN"
          value = var.environment == "prod" ? "http://localhost:3000,https://beta.wisecut.ai,https://app.wisecut.ai" : "http://localhost:3000,https://dev.wisecut.ai,https://beta.wisecut.ai,https://app.wisecut.ai"
        },
        {
          name  = "AYRSHARE_API_KEY"
          value = "2E3098FA-36E042FE-9B2358BC-773384A5"
        },
        {
          name  = "SWAGGER_TITLE"
          value = var.environment == "prod" ? "Wisecut Social Hub API - PRODUCTION" : "Wisecut Social Hub API - DEV"
        },
        {
          name  = "SWAGGER_DESCRIPTION"
          value = var.environment == "prod" ? "API de produção para integração com Ayrshare" : "API de desenvolvimento para integração com Ayrshare"
        },
        {
          name  = "AYRSHARE_DOMAIN"
          value = "id-6ne1y"
        },
        {
          name  = "DATABASE_URL"
          value = var.environment == "prod" ? "postgresql://postgres:WisecutSocial2024!@wisecut-social-hub-dev.cxvacazqi6op.us-east-1.rds.amazonaws.com:5432/wisecut_social_hub" : "postgresql://postgres:WisecutSocial2024!@wisecut-social-hub-dev.cxvacazqi6op.us-east-1.rds.amazonaws.com:5432/wisecut_social_hub"
        },
        {
          name  = "SWAGGER_PATH"
          value = "docs"
        },
        {
          name  = "WISECUT_API_URL"
          value = var.environment == "prod" ? "https://api.wisecut.video/v3" : "https://api.wisecut.video/dev"
        }
      ], var.app_environment_variables)
      
      secrets = var.app_secrets
    }
  ])

  tags = merge(local.default_tags, {
    Name = local.task_family
  })
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  # Allow CodePipeline to update task definition
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [aws_lb_listener.http, aws_lb_listener.https]

  tags = merge(local.default_tags, {
    Name = local.service_name
  })
}

# --------------
# CI/CD Pipeline
# --------------

# CodeStar Connection for Bitbucket
resource "aws_codestarconnections_connection" "bitbucket" {
  name          = "${local.name_prefix}-bitbucket-conn"
  provider_type = "Bitbucket"

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-bitbucket-conn"
  })
}

# S3 Bucket for CodePipeline artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifact_bucket
  force_destroy = true

  tags = merge(local.default_tags, {
    Name = local.artifact_bucket
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${local.name_prefix}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "codebuild_inline" {
  name = "${local.name_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = data.aws_ecr_repository.app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "build" {
  name          = "${local.name_prefix}-build"
  description   = "Build & push image to ECR for ${local.name_prefix}"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    privileged_mode            = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPO"
      value = data.aws_ecr_repository.app.repository_url
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = "app"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = local.buildspec
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/codebuild/${local.name_prefix}"
    }
  }

  build_timeout  = 30
  queued_timeout = 30

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-build"
  })
}

# Buildspec for CodeBuild
locals {
  buildspec = <<-YAML
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG="$ENVIRONMENT-$COMMIT_HASH"
      - IMAGE_URI="$ECR_REPO:$IMAGE_TAG"
      - IMAGE_URI_LATEST="$ECR_REPO:latest"
      - echo Build started on `date`
      - echo Building the Docker image $IMAGE_URI and $IMAGE_URI_LATEST
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - |
        # Usar Dockerfile.prisma-fixed se existir
        if [ -f "Dockerfile.prisma-fixed" ]; then
          echo "Usando Dockerfile.prisma-fixed para build com Prisma..."
          cp Dockerfile.prisma-fixed Dockerfile
        fi
        # Verificar e corrigir problemas do Prisma para produção
        if [ -f "prisma/schema.prisma" ]; then
          echo "Detectado projeto com Prisma, configurando para produção..."
          # Adicionar binaryTargets para compatibilidade com diferentes ambientes
          if ! grep -q "binaryTargets" prisma/schema.prisma; then
            echo "Adicionando binaryTargets ao schema.prisma..."
            sed -i '/provider.*=.*"prisma-client-js"/a \ \ binaryTargets = ["native", "rhel-openssl-3.0.x", "debian-openssl-3.0.x"]' prisma/schema.prisma
          fi
        fi
        # Substituir imagens do Docker Hub por ECR Public se necessário
        if grep -q "FROM node:" Dockerfile; then
          echo "Substituindo imagem node do Docker Hub por ECR Public..."
          sed 's|FROM node:|FROM public.ecr.aws/docker/library/node:|g' Dockerfile > Dockerfile.tmp
          mv Dockerfile.tmp Dockerfile
        fi
      - docker build -t $IMAGE_URI -t $IMAGE_URI_LATEST .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker images...
      - docker push $IMAGE_URI
      - docker push $IMAGE_URI_LATEST
      - echo Writing image definitions file...
      - printf '[{"name":"%s","imageUri":"%s"}]' "$CONTAINER_NAME" "$IMAGE_URI_LATEST" > imagedefinitions.json
      - cat imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
YAML
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name_prefix}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  name = "${local.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "arn:aws:codestar-connections:us-east-1:600035690104:connection/860d93c8-a477-4cd4-bea6-5e9c5c52cc55"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetBuildBatches",
          "codebuild:StartBuildBatch"
        ]
        Resource = aws_codebuild_project.build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}

# CodePipeline
resource "aws_codepipeline" "this" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:us-east-1:600035690104:connection/860d93c8-a477-4cd4-bea6-5e9c5c52cc55"
        FullRepositoryId = "${var.bitbucket_owner}/${var.bitbucket_repo}"
        BranchName       = var.bitbucket_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = aws_ecs_cluster.this.name
        ServiceName = aws_ecs_service.this.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  depends_on = [aws_iam_role_policy.codepipeline_inline]

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-pipeline"
  })
}

# --------------
# Redis ElastiCache - Minimal Configuration
# --------------

# Subnet group for Redis
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-sg"
  subnet_ids = local.subnet_ids

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-redis-subnet-group"
  })
}

# Security group for Redis - allow access from ECS
resource "aws_security_group" "redis" {
  name_prefix = "${local.name_prefix}-redis-"
  vpc_id      = local.vpc_id

  # Allow Redis access from ECS
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Redis cluster - adjustable by environment
resource "aws_elasticache_replication_group" "redis" {
  description          = "Redis for ${local.name_prefix}"
  replication_group_id = "${local.name_prefix}-redis"
  
  # Environment-specific configuration
  port               = 6379
  node_type          = var.environment == "prod" ? "cache.t3.small" : "cache.t3.micro"
  num_cache_clusters = var.environment == "prod" ? 2 : 1
  
  # Network
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]
  
  # Security configuration
  at_rest_encryption_enabled = var.environment == "prod" ? true : false
  transit_encryption_enabled = false
  auth_token                 = null
  
  # Backup configuration 
  snapshot_retention_limit = var.environment == "prod" ? 7 : 0
  snapshot_window         = var.environment == "prod" ? "03:00-04:00" : null
  maintenance_window      = var.environment == "prod" ? "sun:04:00-sun:05:00" : null
  
  # Auto upgrade
  auto_minor_version_upgrade = true

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-redis"
  })
}

# Output Redis info
output "redis_endpoint" {
  description = "Redis endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

