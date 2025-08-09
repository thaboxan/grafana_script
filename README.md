# Grafana on AWS ECS with Terraform

This Terraform configuration deploys Grafana as a containerized application on AWS ECS Fargate, accessible through an Application Load Balancer (ALB).


<svg viewBox="0 0 1000 700" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <!-- Gradients -->
    <linearGradient id="awsGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FF9900;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#FF6600;stop-opacity:1" />
    </linearGradient>
    
    <linearGradient id="vpcGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#E3F2FD;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#BBDEFB;stop-opacity:1" />
    </linearGradient>
    
    <linearGradient id="subnetGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#F0F8E8;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#C8E6C9;stop-opacity:1" />
    </linearGradient>
    
    <linearGradient id="ecsGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#FFF3E0;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#FFCC80;stop-opacity:1" />
    </linearGradient>

    <!-- Arrow marker -->
    <defs>
      <marker id="arrowhead" markerWidth="10" markerHeight="7" 
       refX="0" refY="3.5" orient="auto">
        <polygon points="0 0, 10 3.5, 0 7" fill="#333" />
      </marker>
    </defs>
  </defs>

  <!-- Background -->
  <rect width="1000" height="700" fill="#f8f9fa"/>
  
  <!-- Title -->
  <text x="500" y="30" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="bold" fill="#232F3E">
    Grafana on AWS ECS Fargate - Architecture
  </text>

  <!-- Internet -->
  <circle cx="500" cy="80" r="25" fill="#4CAF50" stroke="#388E3C" stroke-width="2"/>
  <text x="500" y="85" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="white">
    Internet
  </text>

  <!-- AWS Cloud Border -->
  <rect x="50" y="130" width="900" height="520" fill="none" stroke="#FF9900" stroke-width="3" stroke-dasharray="10,5" rx="10"/>
  <text x="70" y="150" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#FF9900">
    AWS Cloud (us-east-1)
  </text>

  <!-- VPC -->
  <rect x="80" y="170" width="840" height="460" fill="url(#vpcGradient)" stroke="#1976D2" stroke-width="2" rx="10"/>
  <text x="100" y="195" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="#1976D2">
    VPC (10.0.0.0/16)
  </text>

  <!-- Internet Gateway -->
  <rect x="450" y="200" width="100" height="40" fill="#FF9900" stroke="#FF6600" stroke-width="2" rx="5"/>
  <text x="500" y="225" text-anchor="middle" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="white">
    Internet Gateway
  </text>

  <!-- Application Load Balancer -->
  <rect x="400" y="280" width="200" height="50" fill="#8E24AA" stroke="#7B1FA2" stroke-width="2" rx="5"/>
  <text x="500" y="300" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="white">
    Application Load Balancer
  </text>
  <text x="500" y="315" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" fill="white">
    (Port 80 → 3000)
  </text>

  <!-- Availability Zone A -->
  <rect x="120" y="360" width="340" height="240" fill="url(#subnetGradient)" stroke="#4CAF50" stroke-width="2" rx="8" stroke-dasharray="5,3"/>
  <text x="140" y="380" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="#2E7D32">
    Availability Zone A
  </text>
  <text x="140" y="395" font-family="Arial, sans-serif" font-size="11" fill="#2E7D32">
    Public Subnet (10.0.1.0/24)
  </text>

  <!-- Availability Zone B -->
  <rect x="540" y="360" width="340" height="240" fill="url(#subnetGradient)" stroke="#4CAF50" stroke-width="2" rx="8" stroke-dasharray="5,3"/>
  <text x="560" y="380" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="#2E7D32">
    Availability Zone B
  </text>
  <text x="560" y="395" font-family="Arial, sans-serif" font-size="11" fill="#2E7D32">
    Public Subnet (10.0.2.0/24)
  </text>

  <!-- ECS Cluster -->
  <rect x="160" y="420" width="260" height="140" fill="url(#ecsGradient)" stroke="#FF8F00" stroke-width="2" rx="8"/>
  <text x="290" y="445" text-anchor="middle" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="#FF8F00">
    ECS Fargate Cluster
  </text>

  <!-- Grafana Container -->
  <rect x="180" y="470" width="220" height="70" fill="#FF5722" stroke="#D84315" stroke-width="2" rx="5"/>
  <text x="290" y="490" text-anchor="middle" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="white">
    Grafana Container
  </text>
  <text x="290" y="505" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" fill="white">
    grafana/grafana:latest
  </text>
  <text x="290" y="520" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" fill="white">
    CPU: 0.5 vCPU | Memory: 1GB
  </text>

  <!-- CloudWatch Logs -->
  <rect x="580" y="470" width="140" height="60" fill="#00BCD4" stroke="#0097A7" stroke-width="2" rx="5"/>
  <text x="650" y="490" text-anchor="middle" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="white">
    CloudWatch Logs
  </text>
  <text x="650" y="505" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="white">
    /ecs/grafana
  </text>
  <text x="650" y="518" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="white">
    14 days retention
  </text>

  <!-- Security Groups -->
  <rect x="750" y="420" width="120" height="80" fill="#9C27B0" stroke="#7B1FA2" stroke-width="2" rx="5"/>
  <text x="810" y="440" text-anchor="middle" font-family="Arial, sans-serif" font-size="11" font-weight="bold" fill="white">
    Security Groups
  </text>
  <text x="810" y="455" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="white">
    ALB: 0.0.0.0/0:80
  </text>
  <text x="810" y="468" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="white">
    ECS: ALB→3000
  </text>
  <text x="810" y="481" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="white">
    All outbound
  </text>

  <!-- Arrows -->
  <!-- Internet to IGW -->
  <line x1="500" y1="105" x2="500" y2="200" stroke="#333" stroke-width="2" marker-end="url(#arrowhead)"/>
  
  <!-- IGW to ALB -->
  <line x1="500" y1="240" x2="500" y2="280" stroke="#333" stroke-width="2" marker-end="url(#arrowhead)"/>
  
  <!-- ALB to ECS -->
  <line x1="450" y1="330" x2="350" y2="420" stroke="#333" stroke-width="2" marker-end="url(#arrowhead)"/>
  
  <!-- ECS to CloudWatch -->
  <line x1="420" y1="500" x2="580" y2="500" stroke="#333" stroke-width="2" marker-end="url(#arrowhead)" stroke-dasharray="5,5"/>

  <!-- Labels for connections -->
  <text x="520" y="125" font-family="Arial, sans-serif" font-size="10" fill="#666">
    HTTP Traffic
  </text>
  
  <text x="370" y="380" font-family="Arial, sans-serif" font-size="10" fill="#666">
    Port 3000
  </text>
  
  <text x="500" y="490" font-family="Arial, sans-serif" font-size="10" fill="#666">
    Logs
  </text>

  <!-- Legend -->
  <rect x="80" y="655" width="840" height="35" fill="#f5f5f5" stroke="#ddd" stroke-width="1" rx="5"/>
  <text x="100" y="675" font-family="Arial, sans-serif" font-size="12" font-weight="bold" fill="#333">
    Key Features:
  </text>
  <text x="200" y="675" font-family="Arial, sans-serif" font-size="11" fill="#666">
    • High Availability across 2 AZs • Auto-scaling with Fargate • Managed Load Balancing • Centralized Logging • Network Security
  </text>

  <!-- Network flow indicators -->
  <circle cx="85" cy="305" r="8" fill="#4CAF50"/>
  <text x="85" y="310" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="white">
    1
  </text>
  <text x="85" y="325" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="#333">
    User Request
  </text>

  <circle cx="85" cy="505" r="8" fill="#FF9800"/>
  <text x="85" y="510" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="white">
    2
  </text>
  <text x="85" y="525" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="#333">
    Load Balance
  </text>

  <circle cx="85" cy="555" r="8" fill="#2196F3"/>
  <text x="85" y="560" text-anchor="middle" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="white">
    3
  </text>
  <text x="85" y="575" text-anchor="middle" font-family="Arial, sans-serif" font-size="9" fill="#333">
    Container Response
  </text>
</svg>
## Architecture Overview

The infrastructure includes:
- **VPC** with public subnets across two availability zones
- **Application Load Balancer** for external access
- **ECS Fargate cluster** running Grafana container
- **Security groups** for network isolation
- **CloudWatch logs** for container logging

```
Internet → ALB → ECS Fargate (Grafana Container)
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.2 installed
- AWS account with necessary permissions

### Required AWS Permissions

Your AWS credentials need the following permissions:
- EC2 (VPC, Subnets, Security Groups, Internet Gateway)
- ECS (Cluster, Service, Task Definition)
- ELB (Application Load Balancer, Target Groups)
- IAM (Roles, Policies)
- CloudWatch (Log Groups)

## Quick Start

1. **Clone or download the configuration**
   ```bash
   # Save the main.tf file in a new directory
   mkdir grafana-aws
   cd grafana-aws
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review the deployment plan**
   ```bash
   terraform plan
   ```

4. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```
   Type `yes` when prompted to confirm.

5. **Access Grafana**
   After deployment completes, Terraform will output the ALB DNS name:
   ```
   alb_dns_name = "grafana-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com"
   ```
   
   Access Grafana at: `http://<alb_dns_name>`

## Default Credentials

- **Username**: `admin`
- **Password**: `ChangeMe123!`

⚠️ **Security Warning**: Change the default password immediately after first login!

## Configuration Details

### Network Configuration
- **VPC CIDR**: `10.0.0.0/16`
- **Public Subnet A**: `10.0.1.0/24`
- **Public Subnet B**: `10.0.2.0/24`
- **Region**: `us-east-1`

### ECS Configuration
- **Launch Type**: Fargate
- **CPU**: 512 (0.5 vCPU)
- **Memory**: 1024 MB (1 GB)
- **Container**: `grafana/grafana:latest`

### Security Groups
- **ALB Security Group**: Allows HTTP (port 80) from anywhere
- **ECS Security Group**: Allows traffic from ALB to Grafana (port 3000)

## Customization

### Change Region
Modify the provider configuration:
```hcl
provider "aws" {
  region = "your-preferred-region"
}
```

### Change Resource Sizing
Modify the ECS task definition:
```hcl
resource "aws_ecs_task_definition" "grafana_task" {
  cpu    = "1024"  # 1 vCPU
  memory = "2048"  # 2 GB
  # ...
}
```

### Add HTTPS Support
To enable HTTPS, you'll need:
1. An SSL certificate (AWS Certificate Manager)
2. Modify the ALB listener to use port 443
3. Update security groups

### Environment Variables
Add more Grafana configuration via environment variables:
```hcl
environment = [
  { name = "GF_SECURITY_ADMIN_USER", value = "admin" },
  { name = "GF_SECURITY_ADMIN_PASSWORD", value = "YourSecurePassword!" },
  { name = "GF_INSTALL_PLUGINS", value = "grafana-clock-panel,grafana-simple-json-datasource" }
]
```

### Persistent Storage
For production use, consider adding EFS for persistent storage:
```hcl
# Add EFS mount target to container definition
mountPoints = [{
  sourceVolume  = "grafana-storage"
  containerPath = "/var/lib/grafana"
}]
```

## Monitoring and Logging

### CloudWatch Logs
Container logs are automatically sent to CloudWatch:
- **Log Group**: `/ecs/grafana`
- **Retention**: 14 days
- **Stream Prefix**: `grafana`

### View Logs
```bash
aws logs describe-log-streams --log-group-name /ecs/grafana
aws logs get-log-events --log-group-name /ecs/grafana --log-stream-name <stream-name>
```

## Troubleshooting

### Common Issues

1. **ECS Service Creation Fails**
   ```
   Error: ClusterNotFoundException: The referenced cluster was inactive
   ```
   **Solution**: The configuration includes timing delays and proper dependencies to prevent this.

2. **Health Check Failures**
   Check the target group health in AWS Console:
   - EC2 → Load Balancers → Target Groups → grafana-tg

3. **Container Won't Start**
   Check CloudWatch logs:
   ```bash
   aws logs tail /ecs/grafana --follow
   ```

4. **Can't Access Grafana**
   - Verify ALB DNS name is correct
   - Check security group rules
   - Ensure service is running: `aws ecs describe-services --cluster grafana-cluster --services grafana-service`

### Debugging Commands

```bash
# Check cluster status
aws ecs describe-clusters --clusters grafana-cluster

# Check service status
aws ecs describe-services --cluster grafana-cluster --services grafana-service

# Check task status
aws ecs list-tasks --cluster grafana-cluster --service-name grafana-service
aws ecs describe-tasks --cluster grafana-cluster --tasks <task-arn>

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

## Costs

Estimated monthly costs (us-east-1):
- **ALB**: ~$16-20/month
- **ECS Fargate**: ~$15-25/month (0.5 vCPU, 1GB RAM)
- **Data Transfer**: Variable based on usage
- **CloudWatch Logs**: ~$0.50-2/month

Total: ~$32-47/month

## Security Considerations

### Production Hardening
1. **Change default password** immediately
2. **Enable HTTPS** with SSL certificate
3. **Restrict ALB access** to specific IP ranges if possible
4. **Use AWS Secrets Manager** for sensitive configuration
5. **Enable VPC Flow Logs** for network monitoring
6. **Regular security updates** of Grafana container

### Secrets Management
Replace hardcoded password with AWS Secrets Manager:
```hcl
# Create secret
resource "aws_secretsmanager_secret" "grafana_admin" {
  name = "grafana-admin-password"
}

# Reference in task definition
secrets = [{
  name      = "GF_SECURITY_ADMIN_PASSWORD"
  valueFrom = aws_secretsmanager_secret.grafana_admin.arn
}]
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

Type `yes` when prompted. This will remove all AWS resources created by this configuration.

## Support

### Terraform Documentation
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [ECS Service Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)

### Grafana Documentation
- [Grafana Docker Image](https://hub.docker.com/r/grafana/grafana/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)

## License

This Terraform configuration is provided as-is for educational and development purposes.
