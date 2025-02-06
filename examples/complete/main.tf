# Data Sources
data "aws_availability_zones" "available" {}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Local Variables
locals {
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  enable_dns_hostnames = true
  name                 = "cltest"
  private_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region               = "ap-southeast-2"
  vpc_cidr             = "10.0.0.0/16"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"

  azs                  = local.azs
  cidr                 = local.vpc_cidr
  enable_dns_hostnames = local.enable_dns_hostnames
  name                 = local.name
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    name = local.name
  }
}

# Security Group
resource "aws_security_group" "ecs" {
  name   = "${local.name}-ecs"
  vpc_id = module.vpc.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow all incoming traffic"
    from_port   = 0
    protocol    = -1
    self        = "false"
    to_port     = 0
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow all outbound traffic"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = {
    Name = "${local.name}-ecs"
  }
}

# ECS Cluster Module
module "ecs_cluster_classic" {
  source = "../.."

  # Core Configuration
  cluster_name            = local.name
  enable_cloudwatch_agent = true
  security_group_ids      = [aws_security_group.ecs.id]

  # VPC Configuration
  vpc = {
    id = module.vpc.vpc_id
    private_subnets = [
      for i, subnet in module.vpc.private_subnets :
      { id = subnet, cidr = module.vpc.private_subnets_cidr_blocks[i] }
    ]
  }

  # Auto Scaling Groups
  autoscaling_groups = [
    {
      name                  = "asg-1"
      min_size              = 1
      max_size              = 6
      desired_capacity      = 3
      image_id              = data.aws_ami.ecs_optimized.id
      instance_type         = "t3a.medium"
      ebs_optimized         = true
      protect_from_scale_in = false

      # Scaling Config
      managed_scaling = {
        status          = "ENABLED"
        target_capacity = 100
      }

      # Metadata Options
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "enabled"
      }

      # Block Device Mappings
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 30
            volume_type = "gp2"
          }
        }
      ]

      # Tags
      tag_specifications = [
        {
          resource_type = "instance"
          tags = {
            Environment = "production"
            Name        = "instance-1"
          }
        }
      ]

      # User Data
      user_data = templatefile("${path.module}/external/ecs.sh.tpl", {
        cluster_name = local.name
      })
    },
    {
      name             = "asg-2"
      min_size         = 1
      max_size         = 4
      desired_capacity = 2
      image_id         = data.aws_ami.ecs_optimized.id
      instance_type    = "t3a.medium"
      ebs_optimized    = true

      # Scaling Config
      managed_scaling = {
        status          = "ENABLED"
        target_capacity = 100
      }

      # Metadata Options
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
        instance_metadata_tags      = "enabled"
      }

      # Block Device Mappings
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 30
            volume_type = "gp2"
          }
        }
      ]

      # Tags
      tag_specifications = [
        {
          resource_type = "instance"
          tags = {
            Environment = "production"
            Name        = "instance-2"
          }
        }
      ]

      # User Data
      user_data = base64encode(templatefile("${path.module}/external/ecs.sh.tpl", {
        cluster_name = local.name
      }))
    }
  ]
}

# Outputs
output "all_module_outputs" {
  description = "All outputs from the ECS module"
  value       = module.ecs_cluster_classic
}
