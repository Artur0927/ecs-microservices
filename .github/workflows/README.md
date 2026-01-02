# GitHub Actions Workflows

## Workflows Overview

### 1. PR CI (`pr-ci.yml`)
Runs on pull requests to `main`:
- **Tests**: Runs backend tests (Python/FastAPI)
- **Docker Build**: Builds images locally (no push to ECR)
- **Terraform Validation**: Runs `fmt`, `validate`, and `plan`

### 2. Deploy to Production (`deploy.yml`)
Runs on push to `main`:
- **Build & Push**: Builds and pushes Docker images to ECR
- **Deploy**: Updates ECS services with new images
- **Environment Protection**: Requires approval via GitHub Environments

## GitHub Environments Setup

To enable approval gates for production deployments:

1. Go to **Settings** → **Environments** in your GitHub repository
2. Create a new environment named `production`
3. Configure protection rules:
   - **Required reviewers**: Add team members who can approve deployments
   - **Wait timer**: Optional delay before deployment (e.g., 5 minutes)
   - **Deployment branches**: Restrict to `main` branch only

## AWS IAM Roles

The workflows use OIDC to authenticate with AWS. Ensure these roles exist:

- **Build Role**: `arn:aws:iam::577713924485:role/github-actions-build-role`
  - Read-only access for Terraform plan
  - ECR read access

- **Deploy Role**: `arn:aws:iam::577713924485:role/github-actions-deploy-role`
  - ECR push permissions
  - ECS update permissions

These roles are configured in `terraform/oidc.tf`.
