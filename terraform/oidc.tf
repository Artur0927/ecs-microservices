resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# -----------------------------------------------------------------------------
# Role 1: Build / Read-Only (For CI Checks)
# Trust Policy: Allows any branch/PR in the repo
# -----------------------------------------------------------------------------
resource "aws_iam_role" "github_build" {
  name = "github-actions-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:Artur0927/ecs-microservices:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_build_ecr" {
  role       = aws_iam_role.github_build.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# S3 and DynamoDB permissions for Terraform state access (read-only for plan)
resource "aws_iam_policy" "github_build_terraform_state" {
  name        = "github-actions-build-terraform-state-policy"
  description = "Read-only access to Terraform state backend for CI plan operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ecs-terraform-state-c042820c"
      },
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ecs-terraform-state-c042820c/ecs-microservices/prod/terraform.tfstate"
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:DescribeTable"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:us-east-1:577713924485:table/terraform-locks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_build_terraform_state" {
  role       = aws_iam_role.github_build.name
  policy_arn = aws_iam_policy.github_build_terraform_state.arn
}

# -----------------------------------------------------------------------------
# Role 2: Deploy (For Image Push & ECS Updates)
# Trust Policy: RESTRICTED to refs/heads/main only
# -----------------------------------------------------------------------------
resource "aws_iam_role" "github_deploy" {
  name = "github-actions-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" : "repo:Artur0927/ecs-microservices:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "github_deploy_least_privilege" {
  name        = "github-actions-deploy-policy"
  description = "Granular permissions for ECR push and ECS deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR: Get Auth Token
      {
        Action   = "ecr:GetAuthorizationToken"
        Effect   = "Allow"
        Resource = "*"
      },
      # ECR: Push to specific repos
      {
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Effect   = "Allow"
        Resource = [
          aws_ecr_repository.backend.arn,
          aws_ecr_repository.frontend.arn
        ]
      },
      # ECS: Update services
      {
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Effect   = "Allow"
        Resource = [
          aws_ecs_service.backend.id,
          aws_ecs_service.frontend.id
        ]
      },
      # ECS: Describe Cluster
      {
        Action   = "ecs:DescribeClusters"
        Effect   = "Allow"
        Resource = aws_ecs_cluster.main.arn
      },
      # IAM: PassRole to ECS Task Execution Role
      {
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = aws_iam_role.ecs_task_execution_role.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
      # Optional: ELB describe for deployments (if checking targets)
      {
        Action   = "elasticloadbalancing:Describe*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_deploy_attach" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy_least_privilege.arn
}

# -----------------------------------------------------------------------------
# Role 3: Terraform (For Manual Infra Ops)
# Trust Policy: RESTRICTED to refs/heads/main only
# -----------------------------------------------------------------------------
resource "aws_iam_role" "github_terraform" {
  name = "github-actions-terraform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" : "repo:Artur0927/ecs-microservices:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# For simplicity in this lab, providing AdministratorAccess to Terraform role 
# but could be further hardened. Terraform needs broad access to manage resources.
resource "aws_iam_role_policy_attachment" "github_terraform_admin" {
  role       = aws_iam_role.github_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# State access only (Backend permissions explicitly required for some contexts)
resource "aws_iam_policy" "github_terraform_backend" {
  name        = "github-actions-tf-backend-policy"
  description = "Access to S3 state and DynamoDB locks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ecs-terraform-state-c042820c"
      },
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::ecs-terraform-state-c042820c/ecs-microservices/prod/terraform.tfstate"
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:dynamodb:us-east-1:577713924485:table/terraform-locks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_terraform_backend_attach" {
  role       = aws_iam_role.github_terraform.name
  policy_arn = aws_iam_policy.github_terraform_backend.arn
}

output "github_build_role_arn" {
  value = aws_iam_role.github_build.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "github_terraform_role_arn" {
  value = aws_iam_role.github_terraform.arn
}
