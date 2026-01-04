<<<<<<< ours
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
=======
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 14
>>>>>>> theirs
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.project_name}-frontend"
<<<<<<< ours
  retention_in_days = 1

  tags = {
    Name = "${var.project_name}-frontend-logs"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend-task"
=======
  retention_in_days = 14
}

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-frontend-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.project_name}-backend"
>>>>>>> theirs
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
<<<<<<< ours
      name      = "${var.project_name}-backend-container"
=======
      name      = "backend"
>>>>>>> theirs
      image     = "${aws_ecr_repository.backend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
<<<<<<< ours
=======
          protocol      = "tcp"
>>>>>>> theirs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
<<<<<<< ours
          "awslogs-group"         = "/ecs/${var.project_name}-backend"
=======
          "awslogs-group"         = aws_cloudwatch_log_group.backend.name
>>>>>>> theirs
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

<<<<<<< ours
# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend-task"
=======
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.project_name}-frontend"
>>>>>>> theirs
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
<<<<<<< ours
      name      = "${var.project_name}-frontend-container"
=======
      name      = "frontend"
>>>>>>> theirs
      image     = "${aws_ecr_repository.frontend.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
<<<<<<< ours
=======
          protocol      = "tcp"
>>>>>>> theirs
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
<<<<<<< ours
          "awslogs-group"         = "/ecs/${var.project_name}-frontend"
=======
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
>>>>>>> theirs
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

<<<<<<< ours
# Backend Service
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-service"
=======
resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend"
>>>>>>> theirs
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
<<<<<<< ours
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
=======
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_tasks.id]
>>>>>>> theirs
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
<<<<<<< ours
    container_name   = "${var.project_name}-backend-container"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener_rule.backend]
}

# Frontend Service
resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend-service"
=======
    container_name   = "backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener_rule.api]
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.project_name}-frontend"
>>>>>>> theirs
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
<<<<<<< ours
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
=======
    subnets         = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    security_groups = [aws_security_group.ecs_tasks.id]
>>>>>>> theirs
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
<<<<<<< ours
    container_name   = "${var.project_name}-frontend-container"
=======
    container_name   = "frontend"
>>>>>>> theirs
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}
