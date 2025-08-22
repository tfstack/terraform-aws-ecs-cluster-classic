############################################
# Provider Configuration
############################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

############################################
# Data Sources
############################################

data "aws_availability_zones" "available" {}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

############################################
# Local Variables
############################################

locals {
  azs             = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  name            = "example"
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  vpc_cidr        = "10.0.0.0/16"

  suffix = random_string.suffix.result

  tags = {
    Environment = "dev"
    Project     = "example"
  }
}

# VPC Module
module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  # Enable Internet Gateway & NAT Gateway
  # A single NAT gateway is used instead of multiple for cost efficiency.
  create_igw       = true
  nat_gateway_type = "single"

  tags = local.tags
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
      for i, subnet in module.vpc.private_subnet_ids :
      { id = subnet, cidr = module.vpc.private_subnet_cidrs[i] }
    ]
  }

  # Auto Scaling Groups
  autoscaling_groups = [
    {
      name                  = "asg-1"
      min_size              = 3
      max_size              = 6
      desired_capacity      = 3
      image_id              = data.aws_ami.ecs_optimized.id
      instance_type         = "t3a.medium"
      ebs_optimized         = true
      protect_from_scale_in = true

      additional_iam_policies = [
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      ]

      managed_termination_protection = "ENABLED"

      # Instance Refresh
      instance_refresh = {
        enabled                      = true
        strategy                     = "Rolling"
        auto_rollback                = false
        min_healthy_percentage       = 100
        max_healthy_percentage       = 100
        instance_warmup              = 300
        scale_in_protected_instances = "Refresh"
        standby_instances            = "Ignore"
        skip_matching                = false
        checkpoint_delay             = 3600
        checkpoint_percentages       = null
        triggers                     = ["launch_template"]
      }

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
            Environment = "dev"
            Name        = "instance-1"
          }
        }
      ]

      # User Data
      user_data = templatefile("${path.module}/external/ecs.sh.tpl", {
        cluster_name = local.name
      })

      use_explicit_launch_template_version = true
    },
    {
      name             = "asg-2"
      min_size         = 3
      max_size         = 6
      desired_capacity = 3
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
            Environment = "dev"
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

variable "slack_webhook_url" {
  description = "Slack Webhook URL for sending notifications"
  type        = string
}


module "ec2_auto_scaling_event" {
  source = "tfstack/event-notifier-slack/aws"

  name   = "${local.name}-ec2-auto-scaling-event"
  suffix = random_string.suffix.result

  eventbridge_rules = [
    {
      name        = "ec2-auto-scaling-event"
      description = "Capture EC2 Auto Scaling events for a specific cluster"
      event_pattern = jsonencode({
        source = ["aws.autoscaling"]
        "detail-type" = [
          # "EC2 Instance-launch Lifecycle Action",
          # "EC2 Instance-terminate Lifecycle Action",
          # "EC2 Instance Launch Successful",
          # "EC2 Instance Terminate Successful",
          "EC2 Instance Launch Unsuccessful",
          "EC2 Instance Terminate Unsuccessful",
          "EC2 Auto Scaling Instance Refresh Checkpoint Reached",
          "EC2 Auto Scaling Instance Refresh Started",
          "EC2 Auto Scaling Instance Refresh Succeeded",
          "EC2 Auto Scaling Instance Refresh Failed",
          "EC2 Auto Scaling Instance Refresh Cancelled",
          "EC2 Auto Scaling Instance Refresh Rollback Started",
          "EC2 Auto Scaling Instance Refresh Rollback Succeeded",
          "EC2 Auto Scaling Instance Refresh Rollback Failed"
        ]
        detail = {
          AutoScalingGroupName = keys(module.ecs_cluster_classic.ecs_autoscaling_group_arns)
        }
      })
    }
  ]

  slack_webhook_url = var.slack_webhook_url
  message_title     = "EC2 Auto Scaling Event"
  message_fields = join(",", [
    "time",
    "region",
    "account",
    "detail-type",
    "source",
    "detail.AutoScalingGroupName"
  ])
  status_colors = join(",", [
    "LAUNCHING:#3498DB",
    "TERMINATING:#F5A623",
    "SUCCESS:#2EB67D",
    "FAILED:#E74C3C",
    "CANCELLED:#FFCC00"
  ])
  status_field = "detail-type"
  status_mapping = join(",", [
    "EC2 Instance-launch Lifecycle Action:LAUNCHING",
    "EC2 Instance-terminate Lifecycle Action:TERMINATING",
    "EC2 Instance Launch Successful:SUCCESS",
    "EC2 Instance Terminate Successful:SUCCESS",
    "EC2 Instance Launch Unsuccessful:FAILED",
    "EC2 Instance Terminate Unsuccessful:FAILED",
    "EC2 Auto Scaling Instance Refresh Checkpoint Reached:SUCCESS",
    "EC2 Auto Scaling Instance Refresh Started:LAUNCHING",
    "EC2 Auto Scaling Instance Refresh Succeeded:SUCCESS",
    "EC2 Auto Scaling Instance Refresh Failed:FAILED",
    "EC2 Auto Scaling Instance Refresh Cancelled:CANCELLED",
    "EC2 Auto Scaling Instance Refresh Rollback Started:TERMINATING",
    "EC2 Auto Scaling Instance Refresh Rollback Succeeded:SUCCESS",
    "EC2 Auto Scaling Instance Refresh Rollback Failed:FAILED"
  ])

  log_retention_days = 1

  tags = {
    Environment = "dev"
    Project     = "example-project"
  }
}
