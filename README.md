# Node.js ECS Template

A complete template for deploying Node.js applications on AWS ECS using Terraform.

## Architecture

- **ECS Fargate**: Serverless container orchestration
- **Application Load Balancer**: Traffic distribution
- **RDS PostgreSQL**: Managed database
- **ElastiCache Redis**: In-memory caching
- **VPC**: Isolated network environment
- **Auto Scaling**: Automatic capacity management

## Directory Structure

```
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/
│       ├── ecs/
│       ├── vpc/
│       ├── security/
│       ├── database/
│       └── load-balancer/
├── docker/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── docker-compose.yml
└── scripts/
```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Docker
- Node.js application ready to deploy

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd appnode-ecs
```

### 2. Configure Variables

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
project_name     = "your-app-name"
environment      = "dev"
region          = "us-east-1"

# Application
app_image       = "your-ecr-repo:latest"
app_port        = 3000
app_cpu         = 256
app_memory      = 512

# Database
db_name         = "your_db_name"
db_username     = "your_db_user"
db_password     = "your_secure_password"
```

### 3. Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 4. Build and Push Docker Image

```bash
# Build image
docker build -f docker/Dockerfile -t your-app .

# Tag for ECR
docker tag your-app:latest <account-id>.dkr.ecr.<region>.amazonaws.com/your-app:latest

# Push to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/your-app:latest
```

### 5. Update ECS Service

```bash
aws ecs update-service --cluster your-app-dev --service your-app-dev-service --force-new-deployment
```

## Environment Variables

Configure these in your Terraform variables:

```hcl
app_environment_variables = [
  {
    name  = "NODE_ENV"
    value = "production"
  },
  {
    name  = "DATABASE_URL"
    value = "postgresql://user:pass@host:5432/db"
  },
  {
    name  = "REDIS_URL"
    value = "redis://host:6379"
  }
]
```

## Customization

### Database

- Modify `terraform/modules/database/` for different database engines
- Update connection strings in application configuration

### Scaling

Configure auto-scaling in `terraform/modules/ecs/variables.tf`:

```hcl
variable "min_capacity" {
  default = 1
}

variable "max_capacity" {
  default = 10
}
```

### Security

- Review security groups in `terraform/modules/security/`
- Update IAM roles and policies as needed
- Configure SSL certificates for HTTPS

## Monitoring

- CloudWatch logs are automatically configured
- Add custom metrics and alarms as needed
- Consider adding APM tools like DataDog or New Relic

## CI/CD

Add GitHub Actions workflow in `.github/workflows/deploy.yml` for automated deployments.

## Cleanup

```bash
cd terraform/environments/dev
terraform destroy
```

## Support

For issues and questions, please create an issue in this repository.