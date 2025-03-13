# Terraform ECS Complete Configuration

This Terraform configuration provisions a **fully functional Amazon ECS cluster** using an **EC2 launch type** with Auto Scaling, networking, and security configurations, including default Instance Refresh for automated rolling updates.

## Features

- Deploys an **ECS Cluster** (`EC2` launch type) with Auto Scaling
- Creates a **VPC** with public and private subnets
- Configures an **Auto Scaling Group** for ECS instances
- Implements **Instance Refresh** for rolling updates
- Sets up **security groups** with inbound and outbound rules
- Supports **CloudWatch Agent** for monitoring
- Uses **Amazon Linux 2 ECS-Optimized AMI** for instances

## Usage

### Deploy the Infrastructure

```hcl
module "ecs_cluster_classic" {
  source = "../.."

  cluster_name            = "cltest"
  enable_cloudwatch_agent = true
  security_group_ids      = [aws_security_group.ecs.id]

  vpc = {
    id = module.vpc.vpc_id
    private_subnets = [
      for i, subnet in module.vpc.private_subnets :
      { id = subnet, cidr = module.vpc.private_subnets_cidr_blocks[i] }
    ]
  }

  autoscaling_groups = [
    {
      name                  = "asg-1"
      min_size              = 3
      max_size              = 6
      desired_capacity      = 3
      image_id              = data.aws_ami.ecs_optimized.id
      instance_type         = "t3a.medium"
      ebs_optimized         = true
      protect_from_scale_in = false

      instance_refresh = {
        enabled                = true
        strategy               = "Rolling"
        auto_rollback          = false
        min_healthy_percentage = 100
        max_healthy_percentage = 100
        instance_warmup        = 300
        scale_in_protected_instances = "Refresh"
        standby_instances      = "Ignore"
        skip_matching          = false
        checkpoint_delay       = 3600
        checkpoint_percentages = null
        triggers               = ["launch_template"]
      }

      managed_scaling = {
        status          = "ENABLED"
        target_capacity = 100
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }

      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 30
            volume_type = "gp2"
          }
        }
      ]

      tag_specifications = [
        {
          resource_type = "instance"
          tags = {
            Environment = "production"
            Name        = "instance-1"
          }
        }
      ]

      user_data = templatefile("${path.module}/external/ecs.sh.tpl", {
        cluster_name = "cltest"
      })
    }
  ]
}
```

### Apply Changes

Run the following commands to initialize and deploy:

```sh
terraform init
terraform apply -auto-approve
```

## Outputs

| Name | Description |
|------|-------------|
| `ecs_cluster_id` | The ARN of the ECS cluster |
| `ecs_cluster_capacity_providers` | The list of ECS cluster capacity providers |
| `ecs_autoscaling_group_arns` | The ARNs of the ECS Auto Scaling Groups |
| `ecs_capacity_providers` | Mapping of Auto Scaling Group names to ECS capacity providers |
| `ecs_iam_policy_arn` | The ARN of the IAM policy for ECS instances |
| `ecs_instance_profile_name` | The name of the IAM instance profile for ECS instances |
| `ecs_instance_role_arn` | The ARN of the IAM role assigned to ECS instances |
| `ecs_launch_template_ids` | Mapping of Auto Scaling Group names to Launch Template IDs |
| `ecs_custom_services` | Information about custom ECS services deployed |
| `all_module_outputs` | All outputs from the ECS module |

## Resources Created

- `aws_vpc`
- `aws_subnet`
- `aws_security_group`
- `aws_autoscaling_group`
- `aws_ecs_cluster`
- `aws_ecs_service`
- `aws_lambda_event_source_mapping`

## License

MIT License.
