# Deactivating the Project to Save AWS Credits

This guide explains how to deactivate/tear down the infrastructure to stop AWS charges.

## Option 1: Complete Infrastructure Destruction (Recommended for Long-Term Savings)

This completely removes all AWS resources. You'll need to run `terraform apply` again if you want to restore.

### Steps:

1. **Review what will be destroyed:**
   ```bash
   cd terraform
   terraform plan -destroy
   ```

2. **Destroy all infrastructure:**
   ```bash
   terraform destroy
   ```

3. **Confirm the destruction** when prompted (type `yes`)

### What gets destroyed:
- ECS Cluster and Services
- Application Load Balancer (ALB)
- ECS Task Definitions
- ECR Repositories (and all images)
- VPC, Subnets, NAT Gateway, Internet Gateway
- Security Groups
- CloudWatch Log Groups
- IAM Roles and Policies (GitHub Actions roles)
- OIDC Provider

**Note:** Terraform state will remain in S3 (minimal cost). The infrastructure code remains in Git.

---

## Option 2: Scale Down to Zero (Quick Deactivation, Keep Infrastructure)

If you want to keep the infrastructure but stop running costs, you can scale services to zero.

### Steps:

1. **Temporarily modify ECS services to desired_count = 0:**

   Edit `terraform/ecs.tf`:
   ```hcl
   # Backend Service
   resource "aws_ecs_service" "backend" {
     # ... other config ...
     desired_count   = 0  # Change from 1 to 0
     # ...
   }
   
   # Frontend Service
   resource "aws_ecs_service" "frontend" {
     # ... other config ...
     desired_count   = 0  # Change from 1 to 0
     # ...
   }
   ```

2. **Apply the changes:**
   ```bash
   cd terraform
   terraform apply
   ```

3. **To restore later**, change `desired_count` back to `1` and run `terraform apply` again.

### Costs still incurred (but minimal):
- ALB (small hourly charge when no traffic)
- NAT Gateway (small hourly charge)
- VPC, Subnets (free)
- ECR storage (if images remain)
- ECS cluster (free)

**Note:** This approach is faster to restore but still incurs some costs.

---

## Option 3: Stop NAT Gateway and ALB (Intermediate Approach)

For a balance between cost savings and restoration speed:

1. **Scale services to 0** (as in Option 2)
2. **Manually delete NAT Gateway and ALB via AWS Console** (or comment out in Terraform and apply)
3. **Restore later** by uncommenting and running `terraform apply`

---

## Recommended Approach

For maximum credit savings: **Use Option 1 (terraform destroy)**

This removes all resources except:
- S3 bucket for Terraform state (minimal storage cost ~$0.023/GB/month)
- DynamoDB table for state locking (on-demand pricing, free tier eligible)

You can always restore later with `terraform apply`.

---

## Restoring After Destruction

When you're ready to restore:

```bash
cd terraform
terraform init  # If needed
terraform plan  # Review changes
terraform apply # Restore infrastructure
```

Then push code to trigger CI/CD deployment.
