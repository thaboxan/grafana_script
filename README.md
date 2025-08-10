# Grafana on AWS ECS with Terraform

This Terraform configuration deploys Grafana as a containerized application on AWS ECS Fargate, accessible through an Application Load Balancer (ALB).



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

This Terraform configuration is provided as-is for educational purposes.
