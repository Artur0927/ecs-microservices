# CI/CD Pipeline Documentation

Detailed documentation of the GitHub Actions workflows and deployment processes.

## Workflow Overview

This repository uses three distinct GitHub Actions workflows, each serving a specific purpose in the development and deployment lifecycle.

## PR CI Workflow

**File**: `.github/workflows/pr-ci.yml`  
**Trigger**: `pull_request` to `main` branch

### Purpose

Validates code changes before merging without requiring AWS access or write permissions.

### Jobs

#### 1. Test Job

- **Runs**: Backend FastAPI tests
- **Dependencies**: Installs production dependencies + test-only dependencies (pytest, pytest-cov, httpx)
- **Output**: Test results and coverage report
- **Failure Impact**: Blocks merge if tests fail

#### 2. Docker Build Job

- **Runs**: After tests pass
- **Actions**: Builds backend and frontend Docker images locally
- **No Push**: Images are not pushed to ECR (safe for PRs)
- **Caching**: Uses GitHub Actions cache for Docker layer caching
- **Tags**: `local/backend:pr-{PR_NUMBER}` and `local/frontend:pr-{PR_NUMBER}`

#### 3. Terraform Validation Job

- **Runs**: Parallel to docker-build
- **Steps**:
  1. `terraform fmt -check -recursive` - Validates code formatting
  2. `terraform init -backend=false` - Initializes without backend (no AWS access needed)
  3. `terraform validate` - Validates syntax and configuration
- **No Plan**: Does not run `terraform plan` (requires backend access)

### Security Model

- **No AWS Credentials**: Workflow does not authenticate with AWS
- **Read-Only**: Only validates code, does not modify infrastructure
- **Safe for PRs**: Cannot accidentally deploy or modify AWS resources

## Deploy to Production Workflow

**File**: `.github/workflows/deploy.yml`  
**Trigger**: `push` to `main` branch

### Purpose

Automatically builds, tags, and deploys application updates to production ECS services.

### Jobs

#### 1. Build and Push Job

**Environment**: `production` (requires approval)

**Steps**:
1. **Debug OIDC Claims**: Safely prints sub/aud/iss claims for troubleshooting
2. **Configure AWS Credentials**: Assumes deploy role via OIDC
3. **Login to ECR**: Authenticates with container registry
4. **Build and Push Backend**: Builds image, tags with `latest` and `git-sha`, pushes to ECR
5. **Build and Push Frontend**: Same process for frontend image

**Image Tagging Strategy**:
- `{ECR_REPO}:latest` - Always points to most recent deployment
- `{ECR_REPO}:{git-sha}` - Immutable tag for specific commit (enables rollbacks)

**Caching**: Docker layer caching via GitHub Actions cache

#### 2. Deploy Job

**Environment**: `production` (requires approval)  
**Dependencies**: Waits for `build-and-push` to complete

**Steps**:
1. **Configure AWS Credentials**: Assumes deploy role via OIDC
2. **Get ALB DNS Name**: Retrieves load balancer DNS for deployment summary
3. **Update Backend Service**: Forces new ECS deployment with latest task definition
4. **Update Frontend Service**: Same for frontend service
5. **Wait for Deployment**: Uses `aws ecs wait services-stable` to ensure services are healthy
6. **Deployment Summary**: Creates GitHub Actions summary with deployment details

**Deployment Process**:
- ECS performs rolling update (zero downtime)
- New tasks start before old tasks terminate
- Health checks ensure new tasks are healthy before routing traffic
- Old tasks are drained and stopped

### Security Model

**OIDC Authentication**:
- No AWS access keys stored in GitHub
- Uses OpenID Connect to assume IAM role
- Trust policy restricts to:
  - Repository: `Artur0927/ecs-microservices`
  - Branch: `main` only
  - Environment: `production` only

**Approval Gates**:
- GitHub Environment `production` requires manual approval
- Deployment paused until approved
- Audit trail of who approved and when

**Permissions**:
- Job-level `id-token: write` - Required for OIDC token generation
- Job-level `contents: read` - Required for code checkout

## Manual Terraform Workflow

**File**: `.github/workflows/terraform-manual.yml`  
**Trigger**: `workflow_dispatch` (manual)

### Purpose

Allows controlled infrastructure changes with human-in-the-loop approval.

### Inputs

- **Environment**: `prod` or `dev` (default: `prod`)
- **Action**: `plan` or `apply` (default: `plan`)
- **Confirm**: Must type "APPLY" to execute apply (safety check)

### Restrictions

- **Branch**: Only runs from `main` branch (`if: github.ref == 'refs/heads/main'`)
- **Apply Confirmation**: Requires typing "APPLY" in confirm field
- **OIDC Role**: Uses terraform role with AdministratorAccess

### Usage

1. Navigate to Actions → "Manual Terraform"
2. Click "Run workflow"
3. Select:
   - Environment: `prod`
   - Action: `plan` (to preview) or `apply` (to execute)
   - Confirm: Type "APPLY" if action is `apply`
4. Review workflow run output

### Security

- **Human Approval**: Apply operations require explicit confirmation
- **Branch Restriction**: Cannot run from feature branches
- **Audit Trail**: All infrastructure changes logged in GitHub Actions

## OIDC Configuration

### Trust Policy Structure

**Deploy Role** (`github-actions-deploy-role`):

```json
{
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    },
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:Artur0927/ecs-microservices:ref:refs/heads/main",
        "repo:Artur0927/ecs-microservices:environment:production"
      ]
    }
  }
}
```

**Key Points**:
- `aud` (audience) must be `sts.amazonaws.com`
- `sub` (subject) changes based on context:
  - Without environment: `repo:OWNER/REPO:ref:refs/heads/BRANCH`
  - With environment: `repo:OWNER/REPO:environment:ENVIRONMENT_NAME`

### Debugging OIDC Issues

The deploy workflow includes a debug step that prints OIDC claims:

```
=== OIDC Token Claims (safe debug) ===
sub: repo:Artur0927/ecs-microservices:environment:production
aud: sts.amazonaws.com
iss: https://token.actions.githubusercontent.com
======================================
```

If role assumption fails, check:
1. The `sub` claim matches trust policy patterns
2. The `aud` claim is `sts.amazonaws.com`
3. Job has `id-token: write` permission
4. Environment name matches trust policy

## Deployment Flow

```
Developer pushes to main
         │
         ▼
Deploy workflow triggered
         │
         ▼
Production environment approval required
         │
         ▼
[Human approval]
         │
         ▼
Build and push images to ECR
         │
         ├─▶ Backend: latest + git-sha
         └─▶ Frontend: latest + git-sha
         │
         ▼
Update ECS services
         │
         ├─▶ Backend service: force-new-deployment
         └─▶ Frontend service: force-new-deployment
         │
         ▼
ECS rolling update
         │
         ├─▶ Start new tasks
         ├─▶ Health checks pass
         ├─▶ Route traffic to new tasks
         └─▶ Drain old tasks
         │
         ▼
Wait for services-stable
         │
         ▼
Deployment complete ✅
```

## Best Practices

### Image Tagging

- Always tag with both `latest` and `git-sha`
- `latest` enables easy rollback to most recent
- `git-sha` enables rollback to specific commit

### Deployment Safety

- Use GitHub Environments for approval gates
- Require code review before merging to `main`
- Monitor deployment logs for errors
- Verify health checks pass after deployment

### Infrastructure Changes

- Always run `terraform plan` before `apply`
- Use Manual Terraform workflow for infrastructure changes
- Review plan output carefully
- Apply during maintenance windows if possible

## Troubleshooting

### Deployment Stuck

If deployment hangs on "Wait for Deployment":

```bash
# Check service status
aws ecs describe-services \
  --cluster ecs-cluster \
  --services ecs-backend-service ecs-frontend-service

# Check task status
aws ecs list-tasks \
  --cluster ecs-cluster \
  --service-name ecs-backend-service
```

### Image Pull Errors

If ECS tasks fail to start:

- Verify image exists in ECR: `aws ecr describe-images --repository-name ecs-microservices-backend`
- Check task definition image URI matches ECR repository
- Verify ECS task execution role has ECR pull permissions

### OIDC Failures

See main README troubleshooting section for OIDC-specific issues.
