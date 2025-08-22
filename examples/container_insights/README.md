# Container Insights Example with Scheduled Tasks

This example demonstrates an ECS cluster with Container Insights and two service types:

- **Continuous Service**: Always running for real-time monitoring
- **Scheduled Service**: Runs every 5 minutes using EventBridge

## Features

- Container Insights enabled for ECS monitoring
- CloudWatch Agent for system-level monitoring
- Auto Scaling Groups for scalable ECS capacity
- Continuous service generating metrics every 10 seconds
- Scheduled service running every 5 minutes via EventBridge
- Two separate CloudWatch dashboards

## Usage

1. **Initialize**:

   ```bash
   cd examples/container_insights
   terraform init
   ```

2. **Deploy**:

   ```bash
   terraform plan
   terraform apply
   ```

3. **Access**:
   - Container Insights: CloudWatch > Insights > Container Insights
   - Dashboards: Use the output URLs

## Configuration

### Services

**Continuous Service** (`continuous-metrics-demo`):

- Always running with 2 instances
- Generates metrics every 10 seconds

**Scheduled Service** (`scheduled-metrics-demo`):

- Runs every 5 minutes when triggered
- No continuous instances (`desired_count = 0`)

### Scheduled Task

```hcl
scheduled_task = {
  schedule_expression = "rate(5 minutes)"
  description        = "Scheduled metrics collection"
  enabled           = true
}
```

### Dashboards

- **Continuous Dashboard**: Monitors continuous service metrics
- **Scheduled Dashboard**: Monitors scheduled service execution

## Outputs

- `continuous_dashboard_url`: Continuous service dashboard
- `scheduled_dashboard_url`: Scheduled service dashboard
- `cluster_info`: Service and dashboard information

## Clean Up

```bash
terraform destroy
```
