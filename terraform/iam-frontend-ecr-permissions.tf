# IAM Policy for Frontend Group - ECR Access
resource "aws_iam_policy" "frontend_ecr_access" {
  name        = "${local.name_prefix}-frontend-ecr-access"
  description = "Allow frontend group to push/pull images to ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRGetAuthorizationToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRRepositoryAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchDeleteImage",
          "ecr:DeleteRepository"
        ]
        Resource = [
          data.aws_ecr_repository.app.arn,
          "${data.aws_ecr_repository.app.arn}/*"
        ]
      },
      {
        Sid    = "ECRCreateRepository"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:TagResource"
        ]
        Resource = "arn:aws:ecr:us-east-1:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}-*"
      }
    ]
  })

  tags = local.default_tags
}

# Attach ECR policy to frontend group
resource "aws_iam_group_policy_attachment" "frontend_ecr_access" {
  group      = "frontend"
  policy_arn = aws_iam_policy.frontend_ecr_access.arn
}

# Output the policy ARN for reference
output "frontend_ecr_policy_arn" {
  description = "ARN of the ECR policy for frontend group"
  value       = aws_iam_policy.frontend_ecr_access.arn
}