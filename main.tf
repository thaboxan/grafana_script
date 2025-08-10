# =============================================================================
# GRAFANA ON AWS ECS FARGATE - TERRAFORM CONFIGURATION
# =============================================================================
# This Terraform configuration deploys Grafana as a containerized application 
# on AWS ECS Fargate with the following architecture:
#
# Internet → Application Load Balancer → ECS Fargate (Grafana Container)
#
# Key Components:
# - VPC with public subnets across multiple AZs for high availability
# - Application Load Balancer for external access and health checking
# - ECS Fargate cluster for serverless container hosting
# - Security groups for network access control
# - CloudWatch for logging and monitoring
# - IAM roles for secure service communication
# =============================================================================

# -----------------------------------------------------------------------------
# TERRAFORM AND PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # AWS provider for infrastructure management
      version = ">= 4.0"         # Minimum version for feature compatibility
    }
  }
  required_version = ">= 1.2"    # Terraform version requirement
}

# AWS provider configuration - deploying to us-east-1 region
provider "aws" {
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# DATA SOURCES
# -----------------------------------------------------------------------------
# Fetch available AZs in the current region for subnet distribution
data "aws_availability_zones" "available" {}

# =============================================================================
# NETWORKING INFRASTRUCTURE
# =============================================================================
# This section creates the core networking components including VPC, subnets,
# internet gateway, and routing tables for public internet access

# -----------------------------------------------------------------------------
# VPC - Virtual Private Cloud
# -----------------------------------------------------------------------------
# Main VPC to host all resources with DNS resolution enabled for ALB functionality
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"    # Private IP space for the VPC
  enable_dns_hostnames = true              # Required for ALB DNS resolution
  tags = { Name = "grafana-vpc" }
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# -----------------------------------------------------------------------------
# Provides internet access to public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "grafana-igw" }
}

# -----------------------------------------------------------------------------
# PUBLIC SUBNETS
# -----------------------------------------------------------------------------
# Two public subnets in different AZs for ALB high availability requirement

# Public Subnet in first availability zone
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"                                      # 256 IP addresses
  availability_zone       = data.aws_availability_zones.available.names[0]    # First AZ
  map_public_ip_on_launch = true                                               # Auto-assign public IPs
  tags                    = { Name = "grafana-public-a" }
}

# Public Subnet in second availability zone
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"                                      # 256 IP addresses
  availability_zone       = data.aws_availability_zones.available.names[1]    # Second AZ
  map_public_ip_on_launch = true                                               # Auto-assign public IPs
  tags                    = { Name = "grafana-public-b" }
}

# -----------------------------------------------------------------------------
# ROUTING CONFIGURATION
# -----------------------------------------------------------------------------
# Route table for public subnets to enable internet access via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  # Route all internet traffic (0.0.0.0/0) through the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "grafana-public-rt" }
}

# Associate route table with public subnet A
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# Associate route table with public subnet B
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================
# Security groups act as virtual firewalls controlling traffic flow between
# components. This follows the principle of least privilege access.

# -----------------------------------------------------------------------------
# ALB SECURITY GROUP
# -----------------------------------------------------------------------------
# Controls external access to the Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "grafana-alb-sg"
  description = "Allow HTTP inbound"
  vpc_id      = aws_vpc.this.id

  # Allow inbound HTTP traffic from anywhere on the internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]               # Open to internet - consider restricting in production
    description = "Allow HTTP from anywhere"
  }

  # Allow all outbound traffic (required for ALB to reach ECS tasks)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                        # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "grafana-alb-sg" }
}

# -----------------------------------------------------------------------------
# ECS SECURITY GROUP
# -----------------------------------------------------------------------------
# Controls access to the Grafana container running on ECS
resource "aws_security_group" "ecs_sg" {
  name        = "grafana-ecs-sg"
  description = "Allow ALB to connect to Grafana on port 3000"
  vpc_id      = aws_vpc.this.id

  # Allow inbound traffic ONLY from the ALB on Grafana's port (3000)
  # This implements security isolation - only ALB can reach the container
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]    # Reference ALB security group
    description     = "Allow ALB to Grafana"
  }

  # Allow all outbound traffic (required for Grafana to fetch plugins, updates, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "grafana-ecs-sg" }
}

# =============================================================================
# APPLICATION LOAD BALANCER (ALB)
# =============================================================================
# The ALB provides external access to Grafana with health checking and 
# high availability across multiple AZs

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER
# -----------------------------------------------------------------------------
# Internet-facing ALB that distributes traffic to ECS tasks
resource "aws_lb" "alb" {
  name               = "grafana-alb"
  internal           = false                                    # Internet-facing (not internal)
  load_balancer_type = "application"                           # Layer 7 load balancer
  security_groups    = [aws_security_group.alb_sg.id]         # Attach ALB security group
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]  # Multi-AZ deployment

  tags = { Name = "grafana-alb" }
}

# -----------------------------------------------------------------------------
# TARGET GROUP
# -----------------------------------------------------------------------------
# Defines how ALB routes traffic to ECS tasks and performs health checks
resource "aws_lb_target_group" "tg" {
  name        = "grafana-tg"
  port        = 3000                                           # Grafana's default port
  protocol    = "HTTP"
  target_type = "ip"                                           # Required for Fargate (not "instance")
  vpc_id      = aws_vpc.this.id

  # Health check configuration to ensure Grafana is responsive
  health_check {
    path                = "/"                                  # Grafana's root path
    interval            = 30                                   # Check every 30 seconds
    timeout             = 5                                    # 5-second timeout per check
    healthy_threshold   = 2                                    # 2 successful checks = healthy
    unhealthy_threshold = 2                                    # 2 failed checks = unhealthy
    matcher             = "200-399"                            # HTTP success codes
  }

  tags = { Name = "grafana-tg" }
}

# -----------------------------------------------------------------------------
# ALB LISTENER
# -----------------------------------------------------------------------------
# Configures ALB to listen on port 80 and forward traffic to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  # Default action: forward all traffic to Grafana target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# =============================================================================
# CLOUDWATCH LOGGING
# =============================================================================
# Centralized logging for ECS container output and application logs

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# -----------------------------------------------------------------------------
# Log group for storing Grafana container logs with retention policy
resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana"                           # Standard ECS log group naming
  retention_in_days = 14                                      # Keep logs for 2 weeks (cost optimization)
}

# =============================================================================
# IAM ROLES AND POLICIES
# =============================================================================
# IAM configuration for ECS task execution with minimal required permissions

# -----------------------------------------------------------------------------
# ECS TASK EXECUTION ROLE
# -----------------------------------------------------------------------------
# This role allows ECS to pull images and write to CloudWatch on behalf of tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole-grafana"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Define who can assume this role (ECS tasks service)
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]              # Only ECS tasks can assume this role
    }
  }
}

# Attach AWS managed policy for ECS task execution (ECR pull, CloudWatch logs)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# =============================================================================
# ECS CLUSTER AND CONTAINER ORCHESTRATION
# =============================================================================
# ECS Fargate provides serverless container hosting with automatic scaling
# and management of underlying infrastructure

# -----------------------------------------------------------------------------
# ECS CLUSTER
# -----------------------------------------------------------------------------
# Enhanced ECS cluster with container insights for monitoring
resource "aws_ecs_cluster" "grafana_cluster" {
  name = "grafana-cluster"

  # Enable container insights for detailed monitoring and logging
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "grafana-cluster"
  }
}

# -----------------------------------------------------------------------------
# CLUSTER CAPACITY PROVIDERS
# -----------------------------------------------------------------------------
# Configure Fargate as the compute capacity provider for serverless containers
resource "aws_ecs_cluster_capacity_providers" "grafana_cluster_cp" {
  cluster_name = aws_ecs_cluster.grafana_cluster.name

  capacity_providers = ["FARGATE"]                            # Use Fargate for serverless containers

  # Default capacity provider strategy
  default_capacity_provider_strategy {
    base              = 1                                      # Minimum number of tasks
    weight            = 100                                    # Percentage of tasks using this provider
    capacity_provider = "FARGATE"
  }
}

# -----------------------------------------------------------------------------
# ECS TASK DEFINITION
# -----------------------------------------------------------------------------
# Defines the Grafana container configuration, resources, and environment
resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "grafana-task"
  requires_compatibilities = ["FARGATE"]                      # Fargate launch type
  network_mode             = "awsvpc"                         # Required for Fargate
  cpu                      = "512"                            # 0.5 vCPU (512 CPU units)
  memory                   = "1024"                           # 1 GB RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  # Container definitions in JSON format
  container_definitions = jsonencode([
    {
      name      = "grafana"                                    # Container name for service reference
      image     = "grafana/grafana:latest"                    # Official Grafana Docker image
      essential = true                                         # Task fails if this container stops

      # Port mapping for container communication
      portMappings = [{
        containerPort = 3000                                   # Grafana's internal port
        protocol      = "tcp"
      }]

      # Environment variables for Grafana configuration
      environment = [
        { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
        { name = "GF_SECURITY_ADMIN_PASSWORD", value = "ChangeMe123!" }
      ]

      # CloudWatch logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "grafana"
        }
      }

      # Container health check to ensure Grafana is responding
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"]
        interval    = 30                                       # Check every 30 seconds
        timeout     = 5                                        # 5-second timeout
        retries     = 3                                        # Retry 3 times before marking unhealthy
        startPeriod = 30                                       # Wait 30 seconds before first check
      }
    }
  ])
}

# -----------------------------------------------------------------------------
# TIMING RESOURCE
# -----------------------------------------------------------------------------
# Add timing delay to ensure cluster is fully ready before service creation
# This prevents race conditions during infrastructure deployment
resource "time_sleep" "wait_for_cluster" {
  depends_on = [
    aws_ecs_cluster.grafana_cluster,
    aws_ecs_cluster_capacity_providers.grafana_cluster_cp
  ]
  create_duration = "30s"                                      # Wait 30 seconds
}

# -----------------------------------------------------------------------------
# ECS SERVICE
# -----------------------------------------------------------------------------
# The ECS service manages the running Grafana tasks and integrates with ALB
# for load balancing and health checking
resource "aws_ecs_service" "grafana_service" {
  name            = "grafana-service"
  cluster         = aws_ecs_cluster.grafana_cluster.id
  task_definition = aws_ecs_task_definition.grafana_task.arn
  desired_count   = 1                                          # Number of running tasks
  launch_type     = "FARGATE"                                  # Serverless container hosting

  # Network configuration for Fargate tasks
  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]  # Deploy across AZs
    security_groups = [aws_security_group.ecs_sg.id]          # Apply ECS security group
    assign_public_ip = true                                    # Required for Fargate in public subnets
  }

  # Load balancer integration
  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn            # Connect to ALB target group
    container_name   = "grafana"                              # Must match container name in task definition
    container_port   = 3000                                   # Grafana's port
  }

  # Dependency management to ensure proper creation order
  depends_on = [
    aws_lb_listener.http,                                     # ALB listener must exist first
    aws_ecs_cluster.grafana_cluster,                         # Cluster must be ready
    aws_ecs_cluster_capacity_providers.grafana_cluster_cp,   # Capacity providers configured
    aws_ecs_task_definition.grafana_task,                    # Task definition must exist
    time_sleep.wait_for_cluster                               # Wait for cluster stabilization
  ]

  # Wait for steady state after creation/updates (recommended for production)
  wait_for_steady_state = true

  # Resource tagging for management and cost allocation
  tags = {
    Name = "grafana-service"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================
# Output values for accessing the deployed Grafana instance

# -----------------------------------------------------------------------------
# ALB DNS NAME OUTPUT
# -----------------------------------------------------------------------------
# Provides the URL for accessing Grafana through the load balancer
output "alb_dns_name" {
  description = "URL to access Grafana"
  value       = aws_lb.alb.dns_name
}
