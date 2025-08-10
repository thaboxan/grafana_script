# Grafana on AWS ECS - Architecture Diagram

## High-Level Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                   INTERNET                                         │
│                                      │                                             │
└──────────────────────────────────────┼─────────────────────────────────────────────┘
                                       │
                                       │ HTTP (Port 80)
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD (us-east-1)                                 │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │                          VPC (10.0.0.0/16)                                 │    │
│  │                                                                             │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                    Internet Gateway (grafana-igw)                   │    │    │
│  │  └─────────────────────────────────────────────────────────────────────┘    │    │
│  │                                      │                                      │    │
│  │                                      │                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │    │
│  │  │              Application Load Balancer (grafana-alb)               │    │    │
│  │  │                         Security Group: alb_sg                     │    │    │
│  │  │                      Ingress: 0.0.0.0/0:80 → :80                  │    │    │
│  │  └─────────────────────────────────────────────────────────────────────┘    │    │
│  │                                      │                                      │    │
│  │                                      │ Forward to Target Group             │    │
│  │                                      │                                      │    │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                       Target Group (grafana-tg)                    │    │    │
│  │  │                    Health Check: / every 30s                       │    │    │
│  │  │                      Target Type: IP (Fargate)                     │    │    │
│  │  └─────────────────────────────────────────────────────────────────────┘    │    │
│  │                                      │                                      │    │
│  │                                      │ Route to ECS Tasks                  │    │
│  │                                      │                                      │    │
│  │  ┌──────────────────────┐                              ┌──────────────────────┐ │    │
│  │  │    Availability      │                              │    Availability      │ │    │
│  │  │    Zone A            │                              │    Zone B            │ │    │
│  │  │                      │                              │                      │ │    │
│  │  │ ┌──────────────────┐ │                              │ ┌──────────────────┐ │ │    │
│  │  │ │ Public Subnet A  │ │                              │ │ Public Subnet B  │ │ │    │
│  │  │ │ (10.0.1.0/24)    │ │                              │ │ (10.0.2.0/24)    │ │ │    │
│  │  │ │                  │ │                              │ │                  │ │ │    │
│  │  │ │ ┌─────────────┐  │ │          OR                  │ │ ┌─────────────┐  │ │ │    │
│  │  │ │ │ ECS Fargate │  │ │    (High Availability)       │ │ │ ECS Fargate │  │ │ │    │
│  │  │ │ │    Task     │  │ │                              │ │ │    Task     │  │ │ │    │
│  │  │ │ │             │  │ │                              │ │ │             │  │ │ │    │
│  │  │ │ │ ┌─────────┐ │  │ │                              │ │ │ ┌─────────┐ │  │ │ │    │
│  │  │ │ │ │ Grafana │ │  │ │                              │ │ │ │ Grafana │ │  │ │ │    │
│  │  │ │ │ │Container│ │  │ │                              │ │ │ │Container│ │  │ │ │    │
│  │  │ │ │ │Port 3000│ │  │ │                              │ │ │ │Port 3000│ │  │ │ │    │
│  │  │ │ │ └─────────┘ │  │ │                              │ │ │ └─────────┘ │  │ │ │    │
│  │  │ │ │             │  │ │                              │ │ │             │  │ │ │    │
│  │  │ │ │ Security    │  │ │                              │ │ │ Security    │  │ │ │    │
│  │  │ │ │ Group:      │  │ │                              │ │ │ Group:      │  │ │ │    │
│  │  │ │ │ ecs_sg      │  │ │                              │ │ │ ecs_sg      │  │ │ │    │
│  │  │ │ │ (ALB→:3000) │  │ │                              │ │ │ (ALB→:3000) │  │ │ │    │
│  │  │ │ └─────────────┘  │ │                              │ │ └─────────────┘  │ │ │    │
│  │  │ └──────────────────┘ │                              │ └──────────────────┘ │ │    │
│  │  └──────────────────────┘                              └──────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                              ECS Cluster                                       │    │
│  │                           (grafana-cluster)                                    │    │
│  │                         Container Insights: Enabled                           │    │
│  │                       Capacity Provider: FARGATE                             │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                            CloudWatch Logs                                     │    │
│  │                          Log Group: /ecs/grafana                              │    │
│  │                          Retention: 14 days                                   │    │
│  │                               │                                               │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │           Container Logs Stream (grafana-xxx-xxx)                      │  │    │
│  │  │  • Application logs from Grafana container                             │  │    │
│  │  │  • Health check results                                                │  │    │
│  │  │  • Startup/shutdown events                                             │  │    │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐    │
│  │                                IAM Roles                                       │    │
│  │                                                                                 │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐    │    │
│  │  │                    ECS Task Execution Role                             │    │    │
│  │  │                  (ecsTaskExecutionRole-grafana)                        │    │    │
│  │  │                                                                         │    │    │
│  │  │  Permissions:                                                           │    │    │
│  │  │  • Pull images from ECR                                                │    │    │
│  │  │  • Write logs to CloudWatch                                            │    │    │
│  │  │  • Decrypt secrets (if using Secrets Manager)                         │    │    │
│  │  └─────────────────────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Network Architecture
- **VPC**: `10.0.0.0/16` - Private cloud network
- **Public Subnet A**: `10.0.1.0/24` in AZ-a
- **Public Subnet B**: `10.0.2.0/24` in AZ-b
- **Internet Gateway**: Provides internet access to public subnets

### Security Groups (Firewall Rules)
```
ALB Security Group (alb_sg):
├── Inbound:  0.0.0.0/0:80 → ALB:80 (HTTP from Internet)
└── Outbound: ALB:all → 0.0.0.0/0:all (All traffic out)

ECS Security Group (ecs_sg):
├── Inbound:  ALB_SG:all → ECS:3000 (Only ALB can reach Grafana)
└── Outbound: ECS:all → 0.0.0.0/0:all (All traffic out)
```

### Data Flow
1. **User Request**: User accesses `http://<alb-dns-name>`
2. **Load Balancer**: ALB receives traffic on port 80
3. **Target Group**: ALB forwards to healthy ECS tasks on port 3000
4. **Container**: Grafana container processes the request
5. **Response**: Response flows back through the same path

### High Availability
- **Multi-AZ Deployment**: ALB spans 2 availability zones
- **Auto-Healing**: ECS automatically replaces unhealthy tasks
- **Health Checks**: ALB and ECS both monitor container health
- **Scalability**: Can easily increase `desired_count` for more instances

### Resource Specifications
```
ECS Task:
├── CPU: 512 units (0.5 vCPU)
├── Memory: 1024 MB (1 GB)
├── Network Mode: awsvpc (required for Fargate)
└── Launch Type: FARGATE (serverless)

Grafana Container:
├── Image: grafana/grafana:latest
├── Port: 3000
├── Admin User: admin
└── Admin Password: ChangeMe123! (should be changed)
```

### Monitoring & Logging
- **Container Insights**: Enabled for detailed ECS monitoring
- **CloudWatch Logs**: Centralized logging with 14-day retention
- **Health Checks**: Multiple layers (ALB + ECS + Container)
- **Metrics**: CPU, memory, network utilization available

### Security Considerations
- **Principle of Least Privilege**: Security groups only allow required traffic
- **Network Isolation**: Container only accessible through ALB
- **IAM Roles**: Minimal permissions for ECS task execution
- **Default Credentials**: Should be changed in production

### Cost Optimization
- **Fargate**: Pay only for used compute resources
- **Log Retention**: 14-day retention to balance cost and compliance
- **Single Instance**: Minimal deployment for cost efficiency
- **Public Subnets**: Avoids NAT Gateway costs for internet access