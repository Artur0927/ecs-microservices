terraform {
  backend "s3" {
    bucket         = "ecs-terraform-state-c042820c"
    key            = "ecs-microservices/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
