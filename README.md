# 🚀 Node.js ECS Deployment Template

[![AWS](https://img.shields.io/badge/AWS-ECS-FF9900?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/ecs/)
[![Terraform](https://img.shields.io/badge/Terraform-v1.0+-623CE4?style=flat&logo=terraform&logoColor=white)](https://terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker&logoColor=white)](https://docker.com/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=flat&logo=github-actions&logoColor=white)](https://github.com/features/actions)

> **Production-ready template for deploying Node.js applications on AWS ECS using Terraform with automated CI/CD pipelines.**

## ✨ Features

| Component | Technology | Description |
|-----------|------------|-------------|
| 🐳 **Container Orchestration** | ECS Fargate | Serverless container management |
| ⚖️ **Load Balancing** | Application Load Balancer | Intelligent traffic distribution |
| 🗄️ **Database** | RDS PostgreSQL | Managed relational database |
| ⚡ **Caching** | ElastiCache Redis | High-performance in-memory cache |
| 🌐 **Networking** | VPC + Subnets | Isolated and secure network |
| 📈 **Auto Scaling** | ECS Service Scaling | Automatic capacity management |
| 🔄 **CI/CD** | GitHub Actions | Automated build, test & deploy |
| 📦 **Infrastructure as Code** | Terraform | Reproducible infrastructure |

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub/       │───▶│  GitHub Actions │───▶│   Amazon ECR    │
│   Source Code   │    │   CI/CD         │    │  Container Reg. │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Application    │◀───│      ECS        │◀───│  Load Balancer  │
│  Load Balancer  │    │    Fargate      │    │   (Internet)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│  RDS PostgreSQL │    │ ElastiCache     │
│    Database     │    │     Redis       │
└─────────────────┘    └─────────────────┘
```

## 📁 Directory Structure

```
📦 appnode-ecs/
├── 🔧 .github/workflows/         # CI/CD pipelines
│   └── deploy.yml               # Automated deployment workflow
├── 🏗️ terraform/                 # Infrastructure as Code
│   ├── environments/            # Environment-specific configs
│   │   ├── dev/                # Development environment
│   │   ├── staging/            # Staging environment
│   │   └── prod/               # Production environment
│   └── modules/                # Reusable Terraform modules
│       ├── ecs/               # ECS Fargate configuration
│       ├── vpc/               # Network infrastructure
│       ├── security/          # Security groups & IAM
│       ├── database/          # RDS PostgreSQL
│       └── load-balancer/     # Application Load Balancer
├── 🐳 docker/                   # Container configuration
│   ├── Dockerfile             # Multi-stage build configuration
│   ├── .dockerignore          # Docker build exclusions
│   └── docker-compose.yml     # Local development setup
├── 🚀 scripts/                  # Deployment automation
│   └── deploy.sh              # One-click deployment script
└── 📚 README.md                # This documentation
```

## ⚡ Quick Start

### 📋 Prerequisites

- ✅ **AWS CLI** configured with appropriate permissions
- ✅ **Terraform** >= 1.0 installed
- ✅ **Docker** installed and running
- ✅ **Node.js application** ready for containerization
- ✅ **GitHub account** for CI/CD (optional)

### 🛠️ Setup Steps

#### 1️⃣ Clone and Setup

```bash
git clone https://github.com/fabgcruz/appnode-ecs.git
cd appnode-ecs
```

#### 2️⃣ Configure Environment

Create `terraform/environments/dev/terraform.tfvars` from the example:

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

Edit the configuration:

```hcl
# 🏷️ Project Configuration
project_name     = "your-app-name"
environment      = "dev"
region          = "us-east-1"

# 🐳 Application Settings
app_image       = "your-ecr-repo:latest"
app_port        = 3000
app_cpu         = 256
app_memory      = 512

# 🗄️ Database Configuration
db_name         = "your_db_name"
db_username     = "your_db_user"
db_password     = "your_secure_password"
```

#### 3️⃣ Deploy Infrastructure

```bash
cd terraform/environments/dev
terraform init        # 🔄 Initialize Terraform
terraform plan        # 📋 Preview changes
terraform apply       # 🚀 Deploy infrastructure
```

#### 4️⃣ **Option A: Automated Deployment with CI/CD** ⭐

Set up GitHub Actions for automated deployments:

1. **Configure Repository Secrets:**
   ```
   AWS_ACCESS_KEY_ID     = your-aws-access-key
   AWS_SECRET_ACCESS_KEY = your-aws-secret-key
   ```

2. **Push to trigger deployment:**
   ```bash
   git add .
   git commit -m "feat: deploy my application"
   git push origin main  # 🚀 Automatic deployment starts!
   ```

#### 4️⃣ **Option B: Manual Deployment**

```bash
# 🐳 Build and push Docker image
docker build -f docker/Dockerfile -t your-app .
docker tag your-app:latest <account-id>.dkr.ecr.<region>.amazonaws.com/your-app:latest

# 🔐 Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# ⬆️ Push to registry
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/your-app:latest

# 🔄 Update ECS service
aws ecs update-service --cluster your-app-dev --service your-app-dev-service --force-new-deployment
```

#### 5️⃣ **One-Click Deployment Script** 🎯

```bash
# 🚀 Use the automated deployment script
./scripts/deploy.sh dev latest
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

## 🔄 CI/CD Pipeline

### AWS CodePipeline Integration

The template includes **AWS CodePipeline** for native AWS CI/CD with:

| Stage | Service | Description |
|-------|---------|-------------|
| 📥 **Source** | CodeCommit/GitHub | Source code integration |
| 🏗️ **Build** | CodeBuild | Docker image build & ECR push |
| 🚀 **Deploy** | ECS Rolling Deploy | Automated service updates |

### Pipeline Features

- ✅ **Automatic Triggers** → Git push to main/develop branches
- ✅ **Multi-Environment** → Separate pipelines for dev/staging/prod
- ✅ **Build Artifacts** → Containerized applications in ECR
- ✅ **Zero-Downtime** → Rolling deployments with health checks
- ✅ **Rollback Support** → Automatic rollback on deployment failure

### CodePipeline Configuration

The infrastructure includes:

```hcl
# CodePipeline with integrated stages
- Source: GitHub/Bitbucket integration
- Build: CodeBuild for Docker containerization  
- Deploy: ECS service update with zero-downtime
```

### Alternative: GitHub Actions

For GitHub-based repositories, use the included workflow:

```bash
# Also includes GitHub Actions workflow as alternative
.github/workflows/deploy.yml  # Complete CI/CD pipeline
```

## Cleanup

```bash
cd terraform/environments/dev
terraform destroy
```

## Support

For issues and questions, please create an issue in this repository.