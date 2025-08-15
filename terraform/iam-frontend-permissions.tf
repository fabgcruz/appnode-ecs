# IAM Permissions for Frontend Group
# Allows frontend group to view CodePipeline builds/deployments, ECS cluster, and CloudWatch logs

# Get the existing frontend group
data "aws_iam_group" "frontend" {
  group_name = "frontend"
}

# Policy for CodePipeline read access
resource "aws_iam_policy" "frontend_codepipeline_read" {
  name        = "${local.name_prefix}-frontend-codepipeline-read"
  description = "Allow frontend group to view CodePipeline builds and deployments for ${local.name_prefix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codepipeline:GetPipeline",
          "codepipeline:GetPipelineExecution",
          "codepipeline:GetPipelineState",
          "codepipeline:ListActionExecutions",
          "codepipeline:ListPipelineExecutions",
          "codepipeline:ListPipelines"
        ]
        Resource = [
          aws_codepipeline.this.arn,
          "${aws_codepipeline.this.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:BatchGetProjects",
          "codebuild:ListBuilds",
          "codebuild:ListBuildsForProject"
        ]
        Resource = [
          aws_codebuild_project.build.arn,
          "${aws_codebuild_project.build.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codepipeline:ListPipelines"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-frontend-codepipeline-read"
  })
}

# Policy for ECS read access
resource "aws_iam_policy" "frontend_ecs_read" {
  name        = "${local.name_prefix}-frontend-ecs-read"
  description = "Allow frontend group to view ECS cluster, services and tasks for ${local.name_prefix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeClusters",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeContainerInstances",
          "ecs:ListClusters",
          "ecs:ListServices",
          "ecs:ListTasks",
          "ecs:ListTaskDefinitions",
          "ecs:ListContainerInstances"
        ]
        Resource = [
          aws_ecs_cluster.this.arn,
          "${aws_ecs_cluster.this.arn}/*",
          aws_ecs_service.this.arn,
          "${aws_ecs_service.this.arn}/*",
          aws_ecs_task_definition.this.arn,
          "${aws_ecs_task_definition.this.arn}/*",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task/${aws_ecs_cluster.this.name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-frontend-ecs-read"
  })
}

# Policy for CloudWatch Logs read access
resource "aws_iam_policy" "frontend_logs_read" {
  name        = "${local.name_prefix}-frontend-logs-read"
  description = "Allow frontend group to view CloudWatch logs for ${local.name_prefix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:DescribeQueries",
          "logs:GetQueryResults"
        ]
        Resource = [
          aws_cloudwatch_log_group.app.arn,
          "${aws_cloudwatch_log_group.app.arn}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-frontend-logs-read"
  })
}

# Policy for Load Balancer read access (useful for monitoring)
resource "aws_iam_policy" "frontend_alb_read" {
  name        = "${local.name_prefix}-frontend-alb-read"
  description = "Allow frontend group to view Load Balancer status for ${local.name_prefix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules"
        ]
        Resource = [
          aws_lb.this.arn,
          "${aws_lb.this.arn}/*",
          aws_lb_target_group.this.arn,
          "${aws_lb_target_group.this.arn}/*",
          aws_lb_listener.http.arn,
          "${aws_lb_listener.http.arn}/*"
        ]
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-frontend-alb-read"
  })
}

# Policy for ECR read access (to see images)
resource "aws_iam_policy" "frontend_ecr_read" {
  name        = "${local.name_prefix}-frontend-ecr-read"
  description = "Allow frontend group to view ECR repository and images for ${local.name_prefix}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages"
        ]
        Resource = data.aws_ecr_repository.app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-frontend-ecr-read"
  })
}

# Attach policies to the frontend group
resource "aws_iam_group_policy_attachment" "frontend_codepipeline_read" {
  group      = data.aws_iam_group.frontend.group_name
  policy_arn = aws_iam_policy.frontend_codepipeline_read.arn
}

resource "aws_iam_group_policy_attachment" "frontend_ecs_read" {
  group      = data.aws_iam_group.frontend.group_name
  policy_arn = aws_iam_policy.frontend_ecs_read.arn
}

resource "aws_iam_group_policy_attachment" "frontend_logs_read" {
  group      = data.aws_iam_group.frontend.group_name
  policy_arn = aws_iam_policy.frontend_logs_read.arn
}

resource "aws_iam_group_policy_attachment" "frontend_alb_read" {
  group      = data.aws_iam_group.frontend.group_name
  policy_arn = aws_iam_policy.frontend_alb_read.arn
}

resource "aws_iam_group_policy_attachment" "frontend_ecr_read" {
  group      = data.aws_iam_group.frontend.group_name
  policy_arn = aws_iam_policy.frontend_ecr_read.arn
}