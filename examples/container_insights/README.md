# Container Insights Example

This example demonstrates how to create an ECS cluster with Container Insights enabled for enhanced monitoring and observability.

## Features

- **Container Insights Enabled**: Built-in ECS monitoring that provides container-level metrics
- **CloudWatch Agent**: System-level monitoring for EC2 instances
- **Auto Scaling Groups**: Scalable ECS capacity with EC2 instances
- **Load Generator Service**: Busybox container that generates CPU and memory activity for realistic metrics
- **Security Best Practices**: Least-privilege IAM policies and secure defaults

## Security Features

This example follows security best practices:

- **Least-Privilege Access**: Uses `AmazonECSTaskExecutionRolePolicy` instead of overly permissive policies
- **No Broad Permissions**: Avoids policies like `CloudWatchLogsFullAccess` in favor of specific, minimal permissions
- **Built-in Monitoring**: Container Insights requires no additional IAM permissions
- **Secure Defaults**: ECS task execution role handles CloudWatch Logs automatically

## Container Insights Benefits

Container Insights provides:

- **Container-level metrics**: CPU, memory, network, and storage utilization

- **Task-level metrics**: Per-task resource consumption and performance
- **Service-level metrics**: Service health and performance indicators
- **Cluster-level metrics**: Overall cluster health and capacity
- **Real-time monitoring**: Metrics available in CloudWatch with minimal latency

## Usage

1. **Initialize the example**:

   ```bash
   cd examples/container_insights
   terraform init
   ```

2. **Review and customize** (optional):

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars as needed
   ```

3. **Deploy the infrastructure**:

   ```bash
   terraform plan
   terraform apply
   ```

4. **Access Container Insights**:
   - Go to CloudWatch > Insights
   - Select "Container Insights" from the dropdown
   - Choose your ECS cluster to view metrics

## Configuration

### Key Variables

- `container_insights = true`: Enables Container Insights monitoring
- `enable_cloudwatch_agent = true`: Enables system-level monitoring
- `cluster_name`: Name of the ECS cluster
- `autoscaling_groups`: EC2 instance configuration for ECS capacity
- `ecs_services`: Container definitions and service configuration

### Load Generator Container

The example includes a **load generator container** that creates realistic metrics:

```hcl
container_definitions = [
  {
    name      = "load-generator"
    image     = "busybox:latest"
    command   = ["sh", "-c", "while true; do dd if=/dev/zero of=/dev/null bs=1M count=100; sleep 2; done"]
  }
]
```

This container:

- **Generates CPU load**: Continuously runs `dd` command to process data
- **Creates memory activity**: Allocates and releases memory blocks
- **Runs indefinitely**: Provides continuous metrics for Container Insights
- **No external dependencies**: Self-contained and simple to deploy

### IAM Policies

The example uses minimal, secure IAM policies:

```hcl
execution_role_policies = [
  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
]
```

This policy provides only the essential permissions needed for ECS task execution and CloudWatch Logs integration.

### Monitoring

The example includes:

- **Container Insights**: Built-in ECS monitoring (enabled by default)

- **CloudWatch Agent**: System metrics collection
- **CloudWatch Logs**: Container log aggregation (handled automatically)
- **Health Checks**: Container health monitoring

## Clean Up

To destroy the infrastructure:

```bash
terraform destroy
```

## Notes

- Container Insights is enabled at the cluster level and applies to all services
- Metrics are automatically collected and available in CloudWatch
- No additional agents or sidecars required for Container Insights
- CloudWatch Agent provides additional system-level metrics
- IAM policies follow the principle of least privilege for enhanced security
