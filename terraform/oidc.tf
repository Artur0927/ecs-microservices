resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# -----------------------------------------------------------------------------
# Role 1: Build / Read-Only (For PRs and CI Checks)
# Trust Policy: Allows any branch/PR in the repo
# Permissions: ECR Read-Only (to pull images/cache)
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

# -----------------------------------------------------------------------------
# Role 2: Deploy / Admin (For Validated Main Calls & Manual Ops)
# Trust Policy: RESTRICTED to refs/heads/main only
# Permissions: AdministratorAccess (Full Deploy Power)
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

resource "aws_iam_role_policy_attachment" "github_deploy_admin" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_build_role_arn" {
  value = aws_iam_role.github_build.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
