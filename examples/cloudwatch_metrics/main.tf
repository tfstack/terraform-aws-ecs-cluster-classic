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

data "aws_region" "current" {}

# Data source for AMI
data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

############################################
# Local Variables
############################################

locals {
  azs                  = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  enable_dns_hostnames = true
  name                 = "example"
  private_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region               = data.aws_region.current.region
  vpc_cidr             = "10.0.0.0/16"

  # CloudWatch metrics configuration
  cloudwatch_metrics = {
    namespace   = "ECS/Demo"
    metric_name = "DemoMetric"
    dimensions = [
      { Name = "ServiceName", Value = "continuous-metrics-demo" },
      { Name = "ClusterName", Value = local.name },
      { Name = "Environment", Value = "demo" }
    ]
  }

  # Dashboard configuration
  dashboard_config = {
    period_seconds   = 60 # 1 minute (more frequent for demo)
    refresh_interval = 30 # 30 seconds (more frequent updates)
    default_stat     = "Average"
    y_axis_min       = 0
    y_axis_max       = 100
  }

  # Demo-specific configurations
  demo_config = {
    metric_generation_interval = 10   # Generate metrics every 10 seconds
    random_value_range         = 100  # Random values 0-100
    enable_high_frequency      = true # Enable high-frequency demo mode
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
    self        = false
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

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "metrics_app" {
  name              = "/ecs/${local.name}/metrics-app"
  retention_in_days = 7

  tags = {
    Name = "${local.name}-metrics-app"
  }
}

# ECS Cluster Module
module "ecs_cluster_classic" {
  source = "../.."

  # Core Configuration
  cluster_name            = local.name
  enable_cloudwatch_agent = true
  security_group_ids      = [aws_security_group.ecs.id]

  # Container Insights (Built-in ECS monitoring)
  # Set to true if you want container-level monitoring
  container_insights = false

  # CloudWatch Agent Configuration (Optional system monitoring)
  cloudwatch_agent_config = {
    enable_metrics              = true # Enable system metrics collection (CPU, Memory, Disk)
    enable_logs                 = true # Enable log collection
    region                      = local.region
    metrics_collection_interval = 60 # Collect metrics every 60 seconds
    logs_collection_interval    = 30 # Collect logs every 30 seconds
  }

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
      min_size              = 1
      max_size              = 3
      desired_capacity      = 2
      image_id              = data.aws_ami.ecs_optimized.id
      instance_type         = "t3a.small"
      ebs_optimized         = true
      protect_from_scale_in = false

      # Tags
      tag_specifications = [
        {
          resource_type = "instance"
          tags = {
            Environment = "demo"
            Name        = "${local.name}-instance"
            Purpose     = "cloudwatch-metrics-demo"
          }
        }
      ]

      # User Data
      user_data = templatefile("${path.module}/external/ecs.sh.tpl", {
        cluster_name = local.name
      })
    }
  ]

  ecs_services = [
    {
      name                = "continuous-metrics-demo"
      desired_count       = 2
      cpu                 = "256"
      memory              = "512"
      scheduling_strategy = "REPLICA"
      propagate_tags      = "TASK_DEFINITION"

      # Task role must allow cloudwatch:PutMetricData
      task_role_arn = module.ecs_cluster_classic.ecs_cloudwatch_metrics_role_arn

      container_definitions = jsonencode([
        {
          name      = "continuous-metrics-generator"
          image     = "public.ecr.aws/aws-cli/aws-cli:latest"
          cpu       = 256
          memory    = 512
          essential = true

          entryPoint = ["sh", "-c"]
          command = [
            join("", [
              "echo 'Continuous CloudWatch Metrics Demo Started (High-Frequency Mode)'; ",
              "while true; do ",
              "VALUE=$(od -An -N2 -tu2 < /dev/urandom | tr -d ' '); ",
              "VALUE=$((VALUE % ${local.demo_config.random_value_range})); ",
              "aws cloudwatch put-metric-data ",
              "--namespace \"$NAMESPACE\" ",
              "--metric-name \"$METRIC_NAME\" ",
              "--unit Count ",
              "--value \"$VALUE\" ",
              "--dimensions ServiceName=\"$SERVICE_NAME\",ClusterName=\"$CLUSTER_NAME\" ",
              "--region \"$AWS_DEFAULT_REGION\"; ",
              "echo \"Continuous metric sent: $VALUE\"; ",
              "sleep ${local.demo_config.metric_generation_interval}; ",
              "done"
            ])
          ]

          environment = [
            { name = "AWS_DEFAULT_REGION", value = local.region },
            { name = "SERVICE_NAME", value = "continuous-metrics-demo" },
            { name = "CLUSTER_NAME", value = local.name },
            { name = "NAMESPACE", value = local.cloudwatch_metrics.namespace },
            { name = "METRIC_NAME", value = local.cloudwatch_metrics.metric_name }
          ]

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = aws_cloudwatch_log_group.metrics_app.name
              awslogs-region        = local.region
              awslogs-stream-prefix = "ecs"
            }
          }

          healthCheck = {
            command     = ["CMD-SHELL", "echo 'healthy' || exit 1"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 60
          }
        }
      ])

      deployment_minimum_healthy_percent = 50
      deployment_maximum_percent         = 200
      health_check_grace_period_seconds  = 60

      network_mode             = "bridge"
      requires_compatibilities = ["EC2"]

      service_tags = {
        Environment = "demo"
        Project     = "ContinuousMetricsDemo"
        Purpose     = "Continuous Demo"
        Service     = "continuous-metrics-demo"
        Type        = "AlwaysRunning"
      }

      task_tags = {
        TaskType = "continuous-metrics-demo"
        Purpose  = "continuous-demo"
        Runtime  = "always-on"
      }
    }
  ]
}

# CloudWatch Dashboard for Continuous Metrics Demo
resource "aws_cloudwatch_dashboard" "continuous_metrics_demo" {
  dashboard_name = "${local.name}-continuous-metrics-demo"

  dashboard_body = jsonencode({
    widgets = [
      # Header Widget
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Continuous Metrics Demo Dashboard (High-Frequency Mode)\n**Service**: ${local.name}-continuous-metrics-demo | **Cluster**: ${local.name} | **Environment**: demo | **Metrics**: Every ${local.demo_config.metric_generation_interval}s | **Dashboard**: ${local.dashboard_config.period_seconds}s intervals"
        }
      },

      # Custom DemoMetric Widget
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            [local.cloudwatch_metrics.namespace, local.cloudwatch_metrics.metric_name, "ServiceName", "continuous-metrics-demo", "ClusterName", local.name]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "Custom ${local.cloudwatch_metrics.metric_name} - Continuous Service"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = local.dashboard_config.y_axis_min
              max       = local.dashboard_config.y_axis_max
              showUnits = false
            }
          }
        }
      },

      # CPU Utilization Widget (ECS Service Level)
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "continuous-metrics-demo", "ClusterName", local.name]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "CPU Utilization - ${local.name}-continuous-metrics-demo"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = local.dashboard_config.y_axis_min
              max       = local.dashboard_config.y_axis_max
              showUnits = false
              label     = "CPU %"
            }
          }
        }
      },

      # Memory Utilization Widget (ECS Service Level)
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "continuous-metrics-demo", "ClusterName", local.name]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "Memory Utilization - ${local.name}-continuous-metrics-demo"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = local.dashboard_config.y_axis_min
              max       = local.dashboard_config.y_axis_max
              showUnits = false
              label     = "Memory %"
            }
          }
        }
      },

      # Metrics Count Widget (replaces Running Task Count)
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [local.cloudwatch_metrics.namespace, local.cloudwatch_metrics.metric_name, "ServiceName", "continuous-metrics-demo", "ClusterName", local.name]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = "SampleCount"
          region  = local.region
          title   = "Metrics Count - ${local.name}-continuous-metrics-demo"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = 0
              showUnits = false
              label     = "Metric Count"
            }
          }
        }
      },

      # Service Metrics Summary Widget
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 24
        height = 6
        properties = {
          metrics = [
            [local.cloudwatch_metrics.namespace, local.cloudwatch_metrics.metric_name, "ServiceName", "continuous-metrics-demo", "ClusterName", local.name, { stat = "Average", period = local.dashboard_config.period_seconds }],
            [local.cloudwatch_metrics.namespace, local.cloudwatch_metrics.metric_name, "ServiceName", "continuous-metrics-demo", "ClusterName", local.name, { stat = "Maximum", period = local.dashboard_config.period_seconds }],
            [local.cloudwatch_metrics.namespace, local.cloudwatch_metrics.metric_name, "ServiceName", "continuous-metrics-demo", "ClusterName", local.name, { stat = "Minimum", period = local.dashboard_config.period_seconds }]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "${local.cloudwatch_metrics.metric_name} Statistics - Average, Max, Min"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = local.dashboard_config.y_axis_min
              max       = local.dashboard_config.y_axis_max
              showUnits = false
              label     = "Metric Value"
            }
          }
        }
      },

      # Debug Information Widget
      {
        type   = "text"
        x      = 0
        y      = 20
        width  = 24
        height = 3
        properties = {
          markdown = "## Debug Information\n**Container Dimensions**: ServiceName=${local.name}-continuous-metrics-demo, ClusterName=${local.name}\n**Dashboard Dimensions**: ServiceName=continuous-metrics-demo, ClusterName=${local.name}\n**Metric Namespace**: ${local.cloudwatch_metrics.namespace}\n**Metric Name**: ${local.cloudwatch_metrics.metric_name}\n**Generation Frequency**: Every ${local.demo_config.metric_generation_interval} seconds"
        }
      }
    ]
  })
}
