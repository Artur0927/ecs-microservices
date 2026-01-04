output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "alb_dns_name" {
<<<<<<< ours
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}
=======
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}
>>>>>>> theirs
