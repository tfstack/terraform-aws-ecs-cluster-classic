# Terraform ECS Complete Configuration

This Terraform configuration sets up a **fully functional Amazon ECS cluster** using an **EC2 launch type** with Auto Scaling, networking, and security configurations.

## Features

- Deploys an **ECS Cluster** (`EC2` launch type) with Auto Scaling
- Creates a **VPC** with public and private subnets
- Configures an **Auto Scaling Group** for ECS instances
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
      name             = "asg-1"
      min_size         = 1
      max_size         = 6
      desired_capacity = 3
      image_id         = data.aws_ami.ecs_optimized.id
      instance_type    = "t3a.medium"
      ebs_optimized    = true

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
| `all_module_outputs` | All outputs from the ECS module |

## Resources Created

- `aws_vpc`
- `aws_subnet`
- `aws_security_group`
- `aws_autoscaling_group`
- `aws_ecs_cluster`
- `aws_ecs_service`
- `aws_ami`

## License

MIT License. Modify and use as needed.
