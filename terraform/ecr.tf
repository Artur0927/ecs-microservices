resource "aws_ecr_repository" "backend" {
  name                 = var.backend_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = var.backend_repo_name
  }
}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_repo_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = var.frontend_repo_name
  }
}
