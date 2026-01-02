# AWS ECS Microservices Infrastructure

[![PR CI](https://github.com/Artur0927/ecs-microservices/actions/workflows/pr-ci.yml/badge.svg)](https://github.com/Artur0927/ecs-microservices/actions/workflows/pr-ci.yml)
[![Deploy to Production](https://github.com/Artur0927/ecs-microservices/actions/workflows/deploy.yml/badge.svg)](https://github.com/Artur0927/ecs-microservices/actions/workflows/deploy.yml)

Production-grade microservices architecture on AWS ECS Fargate with Infrastructure as Code (Terraform) and automated CI/CD pipelines using GitHub Actions.

## Project Overview

This project demonstrates a complete cloud-native microservices deployment:

- **Backend**: FastAPI service providing REST API endpoints (`/api/`, `/health`)
- **Frontend**: Static web application served via Nginx, consuming the backend API
- **Infrastructure**: Fully automated AWS infrastructure provisioning with Terraform
- **CI/CD**: Secure, automated deployment pipelines with OIDC authentication

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet                                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Application Load    │
            │  Balancer (ALB)      │
            │  Public Subnets      │
            └──────────┬───────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│  Frontend       │         │  Backend        │
│  ECS Service    │────────▶│  ECS Service    │
│  (Nginx)        │  /api/  │  (FastAPI)      │
│  Port 80        │         │  Port 8000      │
│                 │         │                 │
│  Private Subnet │         │  Private Subnet │
└─────────────────┘         └─────────────────┘
         │                           │
         └───────────┬───────────────┘
                     │
                     ▼
            ┌─────────────────┐
            │  NAT Gateway    │
            │  (Outbound)     │
            └─────────────────┘
```

### Network Design

- **Public Subnets**: Application Load Balancer, NAT Gateway
- **Private Subnets**: ECS Fargate tasks (backend and frontend services)
- **Security Groups**: Least-privilege networking (ALB → ECS tasks only)
- **Multi-AZ**: High availability across two availability zones

## Tech Stack

### Infrastructure
- **Terraform** 1.6.0+ - Infrastructure as Code
- **AWS Services**:
  - ECS Fargate - Serverless container orchestration
  - ECR - Container registry
  - ALB - Application Load Balancer
  - VPC - Network isolation
  - CloudWatch - Logging and monitoring
  - IAM - Role-based access control with OIDC

### Application
- **Backend**: Python 3.9, FastAPI, Uvicorn
- **Frontend**: Nginx (Alpine), static HTML/JavaScript
- **Containerization**: Docker

### CI/CD
- **GitHub Actions** - Automation pipelines
- **OIDC** - Secure AWS authentication (no long-lived credentials)
- **Docker Buildx** - Layer caching for faster builds

## Local Development

### Prerequisites

- Python 3.9+
- Docker and Docker Compose
- AWS CLI (for Terraform operations)
- Terraform 1.6.0+

### Running Locally

Start both services with Docker Compose:

```bash
docker-compose up --build
```

- **Frontend**: http://localhost
- **Backend API**: http://localhost:8000
- **Health Check**: http://localhost:8000/health

### Backend Development

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install pytest pytest-cov httpx  # Test dependencies
uvicorn app.main:app --reload --port 8000
```

Run tests:

```bash
cd backend
pytest test_main.py -v --cov=app
```

## CI/CD

Three GitHub Actions workflows manage the development and deployment lifecycle:

### 1. PR CI (`pr-ci.yml`)

**Trigger**: Pull requests to `main` branch

**Jobs**:
- **Test**: Runs FastAPI backend tests with coverage
- **Docker Build**: Builds images locally (no push to ECR)
- **Terraform Validation**: Runs `fmt -check`, `init -backend=false`, and `validate`

**Security**: No AWS write access. Safe for PR validation.

**Key Features**:
- Test-only dependencies (pytest, httpx) not included in production images
- Terraform validation without backend access (no state required)
- Docker layer caching for faster builds

### 2. Deploy to Production (`deploy.yml`)

**Trigger**: Push to `main` branch

**Jobs**:
- **Build and Push**: Builds Docker images, tags with `latest` and `git-sha`, pushes to ECR
- **Deploy**: Updates ECS services, waits for stabilization

**Security**:
- Uses GitHub Environment `production` with approval gates
- OIDC authentication (no AWS access keys)
- Job-level `id-token: write` permission required
- Trust policy restricts to `main` branch and `production` environment only

**Image Tagging**:
- `{ECR_REPO}:latest` - Latest deployed version
- `{ECR_REPO}:{git-sha}` - Immutable tag for rollbacks

### 3. Manual Terraform (`terraform-manual.yml`)

**Trigger**: Manual workflow dispatch (Actions → Manual Terraform)

**Features**:
- Plan/Apply operations with human confirmation
- Requires typing "APPLY" to execute apply
- Only runs from `main` branch
- Uses OIDC terraform role with broad permissions

**Usage**:
1. Navigate to Actions → "Manual Terraform"
2. Select environment (prod/dev) and action (plan/apply)
3. For apply: Type "APPLY" in confirmation field
4. Review and approve

## Terraform

### State Management

Terraform state is stored in S3 with DynamoDB locking:

- **Backend**: S3 bucket `ecs-terraform-state-c042820c`
- **State Path**: `ecs-microservices/prod/terraform.tfstate`
- **Locking**: DynamoDB table `terraform-locks`

### Local Operations

**Initialize** (with backend):

```bash
cd terraform
terraform init
```

**Plan**:

```bash
terraform plan
```

**Apply**:

```bash
terraform apply
```

**Format**:

```bash
terraform fmt -recursive
```

### Remote Operations

Use the **Manual Terraform** workflow for infrastructure changes:

- Ensures consistent execution environment
- Requires explicit approval for apply operations
- Uses OIDC authentication

### Key Resources

- **VPC**: `10.0.0.0/16` with public/private subnets
- **ECS Cluster**: `ecs-cluster`
- **Services**: `ecs-backend-service`, `ecs-frontend-service`
- **ALB**: `ecs-alb`
- **ECR Repositories**: `ecs-microservices-backend`, `ecs-microservices-frontend`

## Deployment

### Automatic Deployment

When code is pushed to `main`:

1. **Build**: Docker images built with Buildx (layer caching)
2. **Tag**: Images tagged with `latest` and commit SHA
3. **Push**: Images pushed to ECR repositories
4. **Deploy**: ECS services updated with `force-new-deployment`
5. **Wait**: Workflow waits for services to stabilize
6. **Summary**: Deployment summary with image tags and application URL

### Manual Rollback

Rollback to a previous version:

```bash
aws ecs update-service \
  --cluster ecs-cluster \
  --service ecs-backend-service \
  --task-definition ecs-backend-task:{previous-sha} \
  --force-new-deployment
```

Or use the ECS console to update the task definition image tag.

## Outputs / Access

### Application URL

After deployment, get the ALB DNS name:

```bash
cd terraform
terraform output alb_dns_name
```

Or from AWS Console:
- Navigate to EC2 → Load Balancers
- Find `ecs-alb`
- Copy DNS name

**Application Endpoints**:
- Frontend: `http://{alb-dns-name}/`
- Backend API: `http://{alb-dns-name}/api/`
- Health Check: `http://{alb-dns-name}/api/health`

### Terraform Outputs

```bash
cd terraform
terraform output
```

Available outputs:
- `vpc_id` - VPC ID
- `public_subnet_ids` - Public subnet IDs
- `private_subnet_ids` - Private subnet IDs
- `backend_repository_url` - ECR backend repository URL
- `frontend_repository_url` - ECR frontend repository URL
- `alb_dns_name` - Application Load Balancer DNS name

## Troubleshooting

### OIDC Role Assumption Fails

**Error**: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Causes**:
- Missing `id-token: write` permission at job level
- Trust policy `sub` claim mismatch
- Environment name mismatch in trust policy

**Solution**:
1. Verify job has `permissions.id-token: write`
2. Check trust policy allows: `repo:Artur0927/ecs-microservices:environment:production`
3. Verify `aud` claim is `sts.amazonaws.com`
4. Review debug step output in deploy workflow logs

### Terraform Format Check Fails

**Error**: `terraform fmt -check` fails in PR CI

**Solution**:
```bash
cd terraform
terraform fmt -recursive
git add terraform/
git commit -m "fix: format terraform files"
```

### Backend Tests Fail

**Error**: Import errors or missing dependencies

**Solution**:
```bash
cd backend
pip install -r requirements.txt
pip install pytest pytest-cov httpx
python -m pytest test_main.py -v
```

### Docker Build Fails in CI

**Error**: Build context issues or missing files

**Solution**:
- Verify `.dockerignore` doesn't exclude required files
- Check Dockerfile paths are relative to build context
- Review build logs for specific file not found errors

## Security Notes

### Authentication

- **No Long-Lived Credentials**: All AWS access uses OIDC (OpenID Connect)
- **Role-Based Access**: Separate IAM roles for build, deploy, and terraform operations
- **Least Privilege**: Each role has minimum required permissions

### OIDC Trust Policies

**Deploy Role** (`github-actions-deploy-role`):
- Restricted to `main` branch: `repo:Artur0927/ecs-microservices:ref:refs/heads/main`
- Restricted to production environment: `repo:Artur0927/ecs-microservices:environment:production`
- Audience validation: `aud == sts.amazonaws.com`

**Build Role** (`github-actions-build-role`):
- Read-only access for PR validation
- No write permissions

**Terraform Role** (`github-actions-terraform-role`):
- Administrator access (for infrastructure management)
- Restricted to `main` branch only

### GitHub Environments

The `production` environment requires:
- **Approval Gates**: Manual approval before deployment
- **Branch Protection**: Only `main` branch can deploy
- **Audit Trail**: All deployments logged with commit SHA

### Network Security

- ECS tasks in private subnets (no direct internet access)
- Security groups enforce least-privilege networking
- ALB in public subnets with restricted ingress

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── pr-ci.yml              # PR validation workflow
│       ├── deploy.yml             # Production deployment workflow
│       └── terraform-manual.yml   # Manual infrastructure workflow
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                # FastAPI application
│   ├── Dockerfile
│   ├── requirements.txt
│   └── test_main.py              # Backend tests
├── frontend/
│   ├── conf/
│   │   └── default.conf          # Nginx configuration
│   ├── src/
│   │   └── index.html            # Frontend application
│   └── Dockerfile
├── terraform/
│   ├── alb.tf                    # Application Load Balancer
│   ├── ecr.tf                    # ECR repositories
│   ├── ecs.tf                    # ECS cluster, services, task definitions
│   ├── iam.tf                    # IAM roles for ECS tasks
│   ├── oidc.tf                   # OIDC provider and GitHub Actions roles
│   ├── security_groups.tf         # Security group rules
│   ├── vpc.tf                    # VPC, subnets, routing
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── backend.tf                # S3 backend configuration
│   └── terraform.tfvars          # Variable values
├── docker-compose.yml            # Local development
└── README.md                      # This file
```

## Contributing

1. Create a feature branch from `main`
2. Make changes and ensure tests pass locally
3. Push and create a pull request
4. PR CI will validate:
   - Backend tests pass
   - Docker images build successfully
   - Terraform code is formatted and valid
5. After review and approval, merge to `main`
6. Deployment to production happens automatically (with approval)


Author: Artur Martirosyan
