################################################################################
# Task Role
################################################################################
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "create_log_group_pol" {
  name = "create-log-group-pol"
  role = aws_iam_role.ecs_task_role.id
  #checkov:skip=CKV_AWS_290
  #checkov:skip=CKV_AWS_355
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


################################################################################
# SG
################################################################################
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  vpc_id      = aws_vpc.vpc_app.id
  description = "ALB SG"
  #checkov:skip=CKV_AWS_260
  ingress {
    description = "ingress 80"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "ALB egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "task01" {
  name        = "task01-sg"
  vpc_id      = aws_vpc.vpc_app.id
  description = "task01 SG"

  ingress {
    description     = "Allow port 4545"
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Task01 egress"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# Load Balancer
################################################################################

resource "aws_lb" "alb" {
  name            = "ecs-alb"
  subnets         = [for subnet in aws_subnet.public : subnet.id]
  security_groups = [aws_security_group.alb.id]
  #checkov:skip=CKV_AWS_150
  #checkov:skip=CKV_AWS_131
  #checkov:skip=CKV_AWS_91
  #checkov:skip=CKV2_AWS_28
  #checkov:skip=CKV_AWS_104
  #checkov:skip=CKV2_AWS_20
  enable_deletion_protection = false
  drop_invalid_header_fields = false
}

resource "aws_lb_listener" "listener" {
  #checkov:skip=CKV_AWS_2
  #checkov:skip=CKV_AWS_103
  load_balancer_arn = aws_lb.alb.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "tg" {
  #checkov:skip=CKV_AWS_261
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc_app.id
  target_type = "ip"
}

################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "app_cluster" {
  #checkov:skip=CKV_AWS_65
  name = "app-ecs-cluster"
}

resource "aws_ecs_service" "my_service" {
  name            = "app-ecs-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.task01.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.task01.id]
    subnets         = [for subnet in aws_subnet.private : subnet.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.id
    container_name   = "mario_container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.listener]
}

resource "aws_ecs_task_definition" "task01" {
  #checkov:skip=CKV_AWS_249
  #checkov:skip=CKV_AWS_336
  family                   = "super_mario"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  container_definitions = <<TASK_DEFINITION
  [
    {
      "name": "nodejs-app",
      "image": "docker.io/kaminskypavel/mario:latest@sha256:sha256:e695b3e9680b7b12e9ac4101dd02c554cbda7a90c1d6331b2f8c96c0d06f09a8",
      "cpu": 512,
      "memory": 1024,
      "essential": true,
      "environment": [
        {
          "name": "DEFAULT_AWS_REGION", 
          "value": "${data.aws_region.current.name}"
        }
      ],
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "mario_container",
          "awslogs-region": "${data.aws_region.current.name}",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      }
    }
  ]
  TASK_DEFINITION
}
