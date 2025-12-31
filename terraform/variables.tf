variable "project_name" {
  description = "Project name to be used as a prefix for resources"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of Availability Zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "backend_repo_name" {
  description = "Name of the backend ECR repository"
  type        = string
}

variable "frontend_repo_name" {
  description = "Name of the frontend ECR repository"
  type        = string
}
