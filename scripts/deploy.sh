#!/bin/bash

# Deploy script for Node.js ECS application
# Usage: ./scripts/deploy.sh [environment] [image_tag]

set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}
PROJECT_NAME="your-app-name"

echo "🚀 Deploying $PROJECT_NAME to $ENVIRONMENT environment..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI not configured. Please run 'aws configure'"
    exit 1
fi

# Get AWS account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

if [ -z "$REGION" ]; then
    REGION="us-east-1"
    echo "⚠️  No region configured, using default: $REGION"
fi

ECR_REPOSITORY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$PROJECT_NAME"

echo "📦 Building Docker image..."
docker build -f docker/Dockerfile -t $PROJECT_NAME:$IMAGE_TAG .

echo "🏷️  Tagging image for ECR..."
docker tag $PROJECT_NAME:$IMAGE_TAG $ECR_REPOSITORY:$IMAGE_TAG

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

echo "⬆️  Pushing image to ECR..."
docker push $ECR_REPOSITORY:$IMAGE_TAG

echo "🔄 Updating ECS service..."
CLUSTER_NAME="$PROJECT_NAME-$ENVIRONMENT"
SERVICE_NAME="$PROJECT_NAME-$ENVIRONMENT-service"

aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $REGION

echo "⏳ Waiting for deployment to complete..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION

echo "✅ Deployment completed successfully!"

# Get load balancer URL
LB_ARN=$(aws elbv2 describe-load-balancers \
    --names "$PROJECT_NAME-$ENVIRONMENT-alb" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ "$LB_ARN" != "" ] && [ "$LB_ARN" != "None" ]; then
    LB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns $LB_ARN \
        --query 'LoadBalancers[0].DNSName' \
        --output text \
        --region $REGION)
    echo "🌐 Application URL: http://$LB_DNS"
fi