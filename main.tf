terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "grafana-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "grafana-igw" }
}

# Public Subnet A
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "grafana-public-a" }
}

# Public Subnet B
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "grafana-public-b" }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "grafana-public-rt" }
}

# Associate Route Table with public subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "grafana-alb-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "grafana-alb-sg" }
}

# Security Group for ECS Task (Grafana container)
resource "aws_security_group" "ecs_sg" {
  name        = "grafana-ecs-sg"
  description = "Allow ALB to connect to Grafana on port 3000"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to Grafana"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "grafana-ecs-sg" }
}

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "grafana-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "grafana-alb" }
}

# Target Group for ALB (points to Grafana container)
resource "aws_lb_target_group" "tg" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = { Name = "grafana-tg" }
}

# ALB Listener on port 80 forwarding to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# CloudWatch Log Group for ECS logs
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana"
  retention_in_days = 14
}

# IAM Role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-grafana"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Enhanced ECS Cluster with capacity providers
resource "aws_ecs_cluster" "grafana_cluster" {
  name = "grafana-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "grafana-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "grafana_cluster_cp" {
  cluster_name = aws_ecs_cluster.grafana_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS Task Definition for Grafana
resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "grafana-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true

      portMappings = [{
        containerPort = 3000
        protocol      = "tcp"
      }]

      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = "ChangeMe123!" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "grafana"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

# Add timing delay to ensure cluster is fully ready
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    aws_ecs_cluster.grafana_cluster,
    aws_ecs_cluster_capacity_providers.grafana_cluster_cp
  ]
  create_duration = "30s"
}

# ECS Service that runs the Grafana task and connects it to the ALB
resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.grafana_cluster.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster.grafana_cluster,
    aws_ecs_cluster_capacity_providers.grafana_cluster_cp,
    aws_ecs_task_definition.grafana_task,
    time_sleep.wait_for_cluster
  ]

  # Wait for steady state after creation/updates
  wait_for_steady_state = true

  # Add tags for better resource management
  tags = {
    Name = "grafana-service"
  }
}

# Outputs for convenience
output "alb_dns_name" {
  description = "URL to access Grafana"
  value       = aws_lb.alb.dns_name
}
