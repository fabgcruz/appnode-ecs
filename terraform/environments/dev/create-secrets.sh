#!/bin/bash

# Script to create secrets for Social Hub Dev environment
# Usage: ./create-secrets.sh

set -e

ENVIRONMENT="dev"
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="600035690104"

echo "Creating secrets for Social Hub ${ENVIRONMENT} environment..."

# Function to create or update a secret in Secrets Manager
create_secret() {
    local secret_name=$1
    local secret_value=$2
    local description=$3
    
    echo "Creating/updating secret: ${secret_name}"
    
    # Check if secret exists
    if aws secretsmanager describe-secret --secret-id "${secret_name}" --region "${AWS_REGION}" 2>/dev/null; then
        # Update existing secret
        aws secretsmanager update-secret \
            --secret-id "${secret_name}" \
            --secret-string "${secret_value}" \
            --description "${description}" \
            --region "${AWS_REGION}"
        echo "✅ Updated secret: ${secret_name}"
    else
        # Create new secret
        aws secretsmanager create-secret \
            --name "${secret_name}" \
            --secret-string "${secret_value}" \
            --description "${description}" \
            --region "${AWS_REGION}"
        echo "✅ Created secret: ${secret_name}"
    fi
}

# Function to create or update a parameter in Parameter Store
create_parameter() {
    local param_name=$1
    local param_value=$2
    local description=$3
    
    echo "Creating/updating parameter: ${param_name}"
    
    aws ssm put-parameter \
        --name "${param_name}" \
        --value "${param_value}" \
        --type "SecureString" \
        --description "${description}" \
        --overwrite \
        --region "${AWS_REGION}"
    
    echo "✅ Created/updated parameter: ${param_name}"
}

# Prompt for sensitive values
echo ""
echo "Please provide the following sensitive values:"
echo "------------------------------------------------"

read -p "DATABASE_URL: " DATABASE_URL
read -p "AYRSHARE_API_KEY: " AYRSHARE_API_KEY

# Create secrets in AWS Secrets Manager
echo ""
echo "Creating secrets in AWS Secrets Manager..."
echo "------------------------------------------------"

create_secret \
    "${ENVIRONMENT}/social-hub/database-url" \
    "${DATABASE_URL}" \
    "Database connection string for Social Hub ${ENVIRONMENT}"

create_secret \
    "${ENVIRONMENT}/social-hub/ayrshare-api-key" \
    "${AYRSHARE_API_KEY}" \
    "Ayrshare API key for Social Hub ${ENVIRONMENT}"

echo ""
echo "✅ All secrets created successfully!"
echo ""
echo "Add the following to your terraform.tfvars file:"
echo "------------------------------------------------"
cat <<EOF
app_secrets = [
  {
    name      = "DATABASE_URL"
    valueFrom = "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:${ENVIRONMENT}/social-hub/database-url"
  },
  {
    name      = "AYRSHARE_API_KEY"
    valueFrom = "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:${ENVIRONMENT}/social-hub/ayrshare-api-key"
  }
]
EOF

echo ""
echo "Note: The exact secret version ID will be appended automatically by AWS."
echo "You may need to add the version suffix (e.g., :password::) if required."