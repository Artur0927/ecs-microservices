# AWS ECS Microservices Infrastructure

A production-grade microservices architecture on AWS ECS Fargate with Infrastructure as Code (Terraform) and automated CI/CD pipelines using GitHub Actions.

**Author:** Artur Martirosyan

## Project Overview

This project demonstrates a complete cloud-native microservices deployment:

- **Backend**: FastAPI service providing REST API endpoints (`/api/`, `/health`)
- **Frontend**: Static web application served via Nginx, consuming the backend API
- **Infrastructure**: Fully automated AWS infrastructure provisioning with Terraform
- **CI/CD**: Secure, automated deployment pipelines with OIDC authentication

## Architecture Overview

The infrastructure consists of:

- **VPC**: Isolated network (`10.0.0.0/16`) with public and private subnets across two availability zones
- **Application Load Balancer (ALB)**: Public-facing load balancer in public subnets, routes traffic to backend and frontend services
- **ECS Fargate Cluster**: Container orchestration platform running services in private subnets
- **ECS Services**: Two services (backend and frontend) with separate task definitions
- **ECR Repositories**: Container registries for backend and frontend Docker images
- **CloudWatch Log Groups**: Centralized logging for ECS tasks with 14-day retention
- **IAM Roles**: Separate roles for ECS task execution and GitHub Actions (deploy and terraform operations)
- **Security Groups**: Least-privilege networking rules (ALB → ECS tasks only)
- **NAT Gateway**: Provides outbound internet access for ECS tasks in private subnets

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

## CI/CD Pipeline

The project uses a single unified GitHub Actions workflow (`.github/workflows/ci.yml`) that handles all CI/CD operations.

### When CI Runs

- **Push to main branch**: Triggers the full CI pipeline (tests, Terraform validation, build, deploy)
- **PR merge to main**: When a PR is merged, GitHub creates a push event to main, which triggers CI
- **No CI for open PRs**: The workflow does not run for open pull requests (only after merge via push event)

### CI Pipeline Steps (Automatic)

When code is pushed to `main`, the workflow executes:

1. **Backend Tests**: Runs FastAPI backend tests with coverage
2. **Terraform Validation** (conditional): Only runs if any `.tf` files changed in the commit
   - Format check: `terraform fmt -check -recursive`
   - Init: `terraform init`
   - Validate: `terraform validate`
   - Plan: `terraform plan` (shows what would change)
   - **Note**: Terraform apply is never run automatically
3. **Docker Build**: Builds backend and frontend images with Buildx (layer caching)
4. **ECR Push**: Tags images with `latest` and git commit SHA, pushes to ECR repositories
5. **ECS Deployment**: 
   - Retrieves current task definitions
   - Updates image URIs to use the new commit SHA tag
   - Registers new task definition revisions
   - Updates ECS services with `--force-new-deployment`
   - Waits for services to stabilize

### Manual Terraform Apply

Terraform apply is intentionally manual and requires explicit approval:

1. Navigate to GitHub Actions → "CI" workflow
2. Click "Run workflow"
3. Select the `main` branch
4. Check the "Run Terraform Apply" checkbox
5. Click "Run workflow"
6. The workflow requires approval (protected by the `production` GitHub Environment)
7. After approval, Terraform plan runs first, then apply executes

**Why manual Terraform apply?**

- **Safety**: Infrastructure changes can have significant impact; manual approval prevents accidental modifications
- **Review**: Allows time to review the Terraform plan before applying changes
- **Control**: Separates application deployments (automatic) from infrastructure changes (manual)
- **Audit**: Manual approval creates an explicit audit trail for infrastructure changes

### Authentication: OIDC + IAM

The CI/CD pipeline uses OIDC (OpenID Connect) for AWS authentication—no static AWS access keys are stored.

**How it works:**

1. GitHub Actions generates an OIDC token containing repository and workflow metadata
2. GitHub Actions assumes an AWS IAM role using `sts:AssumeRoleWithWebIdentity`
3. The IAM role's trust policy validates the OIDC token:
   - Repository name must match
   - Branch must be `main`
   - Environment must be `production` (for deploy/apply operations)
4. GitHub Actions receives temporary AWS credentials with permissions scoped to the role

**IAM Roles:**

- **`github-actions-deploy-role`**: Used for ECR push and ECS deployment operations
  - Permissions: ECR push, ECS task definition management, ECS service updates
  - Trust policy restricts to `main` branch and `production` environment
- **`github-actions-terraform-role`**: Used for Terraform apply operations
  - Permissions: Full infrastructure management capabilities
  - Trust policy restricts to `main` branch and `production` environment

**Important**: All IAM roles, policies, and trust policies are fully managed in Terraform (`terraform/oidc.tf`). No manual IAM configuration is required, ensuring infrastructure-as-code principles are maintained and preventing configuration drift.

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

**Apply** (use GitHub Actions workflow for production):

```bash
terraform apply
```

**Format**:

```bash
terraform fmt -recursive
```

### Key Resources

- **VPC**: `10.0.0.0/16` with public/private subnets
- **ECS Cluster**: `ecs-cluster`
- **Services**: `ecs-backend-service`, `ecs-frontend-service`
- **Task Definitions**: `ecs-backend-task`, `ecs-frontend-task`
- **ALB**: `ecs-alb`
- **ECR Repositories**: `ecs-microservices-backend`, `ecs-microservices-frontend`

## Deployment

### Automatic Deployment

When code is pushed to `main`:

1. **Build**: Docker images built with Buildx (layer caching)
2. **Tag**: Images tagged with `latest` and commit SHA
3. **Push**: Images pushed to ECR repositories
4. **Deploy**: ECS services updated with new task definitions and `--force-new-deployment`
5. **Wait**: Workflow waits for services to stabilize
6. **Summary**: Deployment summary with image tags and task definition ARNs

### Manual Rollback

Rollback to a previous version:

```bash
aws ecs update-service \
  --cluster ecs-cluster \
  --service ecs-backend-service \
  --task-definition ecs-backend-task:{previous-revision-number} \
  --force-new-deployment
```

Or use the ECS console to update the task definition revision.

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
- `ecs_cluster_name` - ECS cluster name

## Troubleshooting

### OIDC Role Assumption Fails

**Error**: `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Causes**:
- Missing `id-token: write` permission at job level
- Trust policy `sub` claim mismatch (branch/environment)
- Environment name mismatch in trust policy

**Solution**:
1. Verify job has `permissions.id-token: write`
2. Check trust policy allows: `repo:Artur0927/ecs-microservices:ref:refs/heads/main` and `repo:Artur0927/ecs-microservices:environment:production`
3. Verify `aud` claim is `sts.amazonaws.com`
4. Review debug step output in workflow logs
5. Check IAM role trust policy in `terraform/oidc.tf`

### Terraform Format Check Fails

**Error**: `terraform fmt -check` fails in CI

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

### ECS Deployment Fails

**Error**: `AccessDeniedException` when updating ECS services

**Solution**:
1. Verify the `github-actions-deploy-role` has required ECS permissions
2. Check IAM policy in `terraform/oidc.tf` includes:
   - `ecs:DescribeTaskDefinition`
   - `ecs:RegisterTaskDefinition`
   - `ecs:UpdateService`
   - `ecs:DescribeServices`
   - `ecs:DescribeTasks`
3. Ensure `iam:PassRole` permission is granted for the ECS task execution role
4. Apply Terraform changes if IAM policies were updated

## Security Notes

### Authentication

- **No Long-Lived Credentials**: All AWS access uses OIDC (OpenID Connect)
- **Role-Based Access**: Separate IAM roles for deploy and terraform operations
- **Least Privilege**: Each role has minimum required permissions
- **Infrastructure as Code**: All IAM roles and policies are managed in Terraform (`terraform/oidc.tf`), preventing manual configuration drift

### OIDC Trust Policies

**Deploy Role** (`github-actions-deploy-role`):
- Restricted to `main` branch: `repo:Artur0927/ecs-microservices:ref:refs/heads/main`
- Restricted to production environment: `repo:Artur0927/ecs-microservices:environment:production`
- Audience validation: `aud == sts.amazonaws.com`

**Terraform Role** (`github-actions-terraform-role`):
- Infrastructure management permissions
- Restricted to `main` branch and `production` environment

### GitHub Environments

The `production` environment requires:
- **Approval Gates**: Manual approval before deployment and Terraform apply
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
│       └── ci.yml                    # Unified CI/CD workflow
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py                   # FastAPI application
│   ├── Dockerfile
│   ├── requirements.txt
│   └── test_main.py                  # Backend tests
├── frontend/
│   ├── conf/
│   │   └── default.conf              # Nginx configuration
│   ├── src/
│   │   └── index.html                # Frontend application
│   └── Dockerfile
├── terraform/
│   ├── alb.tf                        # Application Load Balancer
│   ├── ecr.tf                        # ECR repositories
│   ├── ecs.tf                        # ECS cluster, services, task definitions
│   ├── iam.tf                        # IAM roles for ECS tasks
│   ├── oidc.tf                       # OIDC provider and GitHub Actions roles
│   ├── security_groups.tf            # Security group rules
│   ├── vpc.tf                        # VPC, subnets, routing
│   ├── variables.tf                  # Input variables
│   ├── outputs.tf                    # Output values
│   ├── backend.tf                    # S3 backend configuration
│   └── terraform.tfvars              # Variable values
├── docker-compose.yml                # Local development
└── README.md                         # This file
```

## Contributing

1. Create a feature branch from `main`
2. Make changes and ensure tests pass locally
3. Push and create a pull request
4. After review and approval, merge to `main`
5. CI pipeline runs automatically on merge:
   - Backend tests execute
   - Docker images build and push to ECR
   - ECS services deploy automatically (with approval)
6. For infrastructure changes:
   - Modify Terraform files
   - Use GitHub Actions workflow with "Run Terraform Apply" to apply changes (requires approval)

## License

[Add your license here]
