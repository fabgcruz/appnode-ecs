# Social Hub ECS - Dev Environment Terraform Configuration

## Overview
This Terraform configuration manages the Social Hub ECS infrastructure for the development environment.

## Setup

### 1. Configure Variables
Copy the example variables file and customize it:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values.

### 2. Managing Sensitive Environment Variables

For security, sensitive values like API keys and database passwords should be stored in AWS Secrets Manager or Parameter Store, not in the Terraform files.

#### Option A: AWS Secrets Manager
```bash
# Create a secret for the database URL
aws secretsmanager create-secret \
  --name dev/social-hub/database-url \
  --secret-string "postgresql://user:pass@host:5432/dbname" \
  --region us-east-1

# Create a secret for API keys
aws secretsmanager create-secret \
  --name dev/social-hub/ayrshare-api-key \
  --secret-string "your-api-key-here" \
  --region us-east-1
```

Then reference in terraform.tfvars:
```hcl
app_secrets = [
  {
    name      = "DATABASE_URL"
    valueFrom = "arn:aws:secretsmanager:us-east-1:600035690104:secret:dev/social-hub/database-url"
  },
  {
    name      = "AYRSHARE_API_KEY"
    valueFrom = "arn:aws:secretsmanager:us-east-1:600035690104:secret:dev/social-hub/ayrshare-api-key"
  }
]
```

#### Option B: AWS Systems Manager Parameter Store
```bash
# Create a secure parameter for sensitive data
aws ssm put-parameter \
  --name "/dev/social-hub/database-url" \
  --value "postgresql://user:pass@host:5432/dbname" \
  --type SecureString \
  --region us-east-1

aws ssm put-parameter \
  --name "/dev/social-hub/ayrshare-api-key" \
  --value "your-api-key-here" \
  --type SecureString \
  --region us-east-1
```

Then reference in terraform.tfvars:
```hcl
app_secrets = [
  {
    name      = "DATABASE_URL"
    valueFrom = "arn:aws:ssm:us-east-1:600035690104:parameter/dev/social-hub/database-url"
  },
  {
    name      = "AYRSHARE_API_KEY"
    valueFrom = "arn:aws:ssm:us-east-1:600035690104:parameter/dev/social-hub/ayrshare-api-key"
  }
]
```

### 3. Initialize and Apply Terraform

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

## Environment Variables

### Non-Sensitive Variables
These can be safely stored in `terraform.tfvars`:
- `AYRSHARE_API_URL`
- `AYRSHARE_DOMAIN`
- `AYRSHARE_SECRET_NAME`
- `PADDLE_BASE_URL`
- `CORS_ORIGIN`
- `WISECUT_API_URL`

### Sensitive Variables
These should be stored in AWS Secrets Manager or Parameter Store:
- `DATABASE_URL` - Database connection string
- `AYRSHARE_API_KEY` - Ayrshare API key
- Any other API keys or passwords

## IAM Permissions

The ECS task execution role needs permissions to access the secrets. This is automatically configured in the Terraform, but ensure the following policy is attached:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:600035690104:secret:dev/social-hub/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:us-east-1:600035690104:parameter/dev/social-hub/*"
      ]
    }
  ]
}
```

## Updating Environment Variables

To add or modify environment variables:

1. For non-sensitive values: Update the `app_environment_variables` list in `terraform.tfvars`
2. For sensitive values: Create/update the secret in AWS, then add to `app_secrets` list
3. Run `terraform apply` to update the ECS task definition
4. The ECS service will automatically deploy the new task definition

## Best Practices

1. **Never commit sensitive values** to version control
2. **Use different secrets** for each environment (dev, staging, prod)
3. **Rotate secrets regularly** using AWS Secrets Manager rotation
4. **Monitor secret access** using CloudTrail
5. **Use least privilege** IAM policies for secret access

## Troubleshooting

### Task fails to start
- Check CloudWatch logs: `/ecs/dev-social-hub-task`
- Verify all required environment variables are set
- Ensure secrets exist and IAM permissions are correct

### Health check failures
- Verify the application is listening on port 3000
- Check that the `/health` endpoint returns HTTP 200
- Review security group rules for port 3000

### Secret access errors
- Verify the secret ARN is correct
- Check IAM permissions for the task execution role
- Ensure the secret exists in the correct region