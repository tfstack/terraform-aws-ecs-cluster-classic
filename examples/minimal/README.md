# Terraform ECS Minimal Configuration

This Terraform configuration sets up an **Amazon ECS cluster** using an **EC2 launch type** with Auto Scaling, VPC, and security groups.

## Features

- Deploys an **ECS Cluster** (`EC2` launch type)
- Creates a **VPC** with private and public subnets
- Configures an **Auto Scaling Group** for ECS instances
- Sets up **security groups** with inbound/outbound rules
- Supports **CloudWatch Agent** for monitoring

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
      name             = "asg-1"
      min_size         = 1
      max_size         = 6
      desired_capacity = 3
      image_id         = data.aws_ami.ecs_optimized.id
      instance_type    = "t3a.medium"
      ebs_optimized    = true

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

  ecs_services = [
    {
      name          = "web-app"
      desired_count = 3
      cpu           = "256"
      memory        = "512"

      execution_role_policies = [
        "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]

      container_definitions = jsonencode([
        {
          name      = "nginx"
          image     = "nginx:latest"
          cpu       = 256
          memory    = 512
          essential = true
          portMappings = [{
            containerPort = 80
            hostPort      = 0
          }]
          healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost || exit 1"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 10
          }
        }
      ])
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

## Resources Created

- `aws_vpc`
- `aws_subnet`
- `aws_security_group`
- `aws_autoscaling_group`
- `aws_ecs_cluster`
- `aws_ecs_service`

## License

MIT License. Modify and use as needed.
