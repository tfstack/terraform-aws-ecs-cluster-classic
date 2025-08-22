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
  container_insights = true

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
    # Service 1: Always running (continuous)
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
    },

    # Service 2: Scheduled only (runs every 5 minutes)
    {
      name                = "scheduled-metrics-demo"
      desired_count       = 0 # No continuous instances - only runs when scheduled
      cpu                 = "256"
      memory              = "512"
      scheduling_strategy = "REPLICA"
      propagate_tags      = "TASK_DEFINITION"

      # Task role must allow cloudwatch:PutMetricData
      task_role_arn = module.ecs_cluster_classic.ecs_cloudwatch_metrics_role_arn

      container_definitions = jsonencode([
        {
          name      = "scheduled-metrics-demo"
          image     = "public.ecr.aws/aws-cli/aws-cli:latest"
          cpu       = 256
          memory    = 512
          essential = true

          entryPoint = ["sh", "-c"]
          command = [
            join("", [
              "echo 'Scheduled Metrics Collection Started'; ",
              "VALUE=$(od -An -N2 -tu2 < /dev/urandom | tr -d ' '); ",
              "VALUE=$((VALUE % ${local.demo_config.random_value_range})); ",
              "aws cloudwatch put-metric-data ",
              "--namespace \"$NAMESPACE\" ",
              "--metric-name \"ScheduledMetric\" ",
              "--unit Count ",
              "--value \"$VALUE\" ",
              "--dimensions ServiceName=\"$SERVICE_NAME\",ClusterName=\"$CLUSTER_NAME\",Type=\"Scheduled\" ",
              "--region \"$AWS_DEFAULT_REGION\"; ",
              "echo \"Scheduled metric sent: $VALUE\"; ",
              "echo 'Scheduled task completed successfully'"
            ])
          ]

          environment = [
            { name = "AWS_DEFAULT_REGION", value = local.region },
            { name = "SERVICE_NAME", value = "scheduled-metrics-demo" },
            { name = "CLUSTER_NAME", value = local.name },
            { name = "NAMESPACE", value = local.cloudwatch_metrics.namespace },
            { name = "METRIC_NAME", value = "ScheduledMetric" }
          ]

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = aws_cloudwatch_log_group.metrics_app.name
              awslogs-region        = local.region
              awslogs-stream-prefix = "ecs"
            }
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
        Project     = "ScheduledMetricsDemo"
        Purpose     = "Scheduled Collection"
        Service     = "scheduled-metrics-demo"
        Type        = "ScheduledOnly"
      }

      task_tags = {
        TaskType = "scheduled-metrics-demo"
        Purpose  = "scheduled-collection"
        Runtime  = "scheduled"
      }

      # Scheduled task configuration - runs every minute
      scheduled_task = {
        schedule_expression = "rate(1 minute)"
        description         = "Scheduled metrics collection every minute"
        enabled             = true
        eventbridge_rule_tags = {
          Environment = "demo"
          Purpose     = "scheduled-metrics"
        }
      }
    }
  ]

  depends_on = [
    aws_cloudwatch_log_group.metrics_app
  ]
}

# CloudWatch Metric Filters for Scheduled Task Monitoring
resource "aws_cloudwatch_log_metric_filter" "scheduled_task_started" {
  name           = "scheduled-task-started"
  log_group_name = aws_cloudwatch_log_group.metrics_app.name

  pattern = "Scheduled Metrics Collection Started"

  metric_transformation {
    name      = "ScheduledTaskStarted"
    namespace = "ECS/TaskMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "scheduled_task_completed" {
  name           = "scheduled-task-completed"
  log_group_name = aws_cloudwatch_log_group.metrics_app.name

  pattern = "Scheduled task completed successfully"

  metric_transformation {
    name      = "ScheduledTaskCompleted"
    namespace = "ECS/TaskMetrics"
    value     = "1"
  }
}


# CloudWatch Dashboard for Continuous Service Only
resource "aws_cloudwatch_dashboard" "continuous_service_demo" {
  dashboard_name = "${local.name}-continuous-service-demo"

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
          markdown = "# Continuous Service Dashboard\n**Service**: ${local.name}-continuous-metrics-demo | **Cluster**: ${local.name} | **Type**: Always Running | **Instances**: 2 | **Metrics**: Every ${local.demo_config.metric_generation_interval}s"
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
            [
              local.cloudwatch_metrics.namespace,
              local.cloudwatch_metrics.metric_name,
              "ServiceName",
              "continuous-metrics-demo",
              "ClusterName", local.name,
            ]
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
              label     = "Metric Value"
            }
          }
        }
      },

      # CPU Utilization Widget
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ServiceName",
              "continuous-metrics-demo",
              "ClusterName",
              local.name
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "CPU Utilization - Continuous Service"
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

      # Memory Utilization Widget
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ServiceName",
              "continuous-metrics-demo",
              "ClusterName", local.name,
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "Memory Utilization - Continuous Service"
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

      # Metrics Count Widget
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              local.cloudwatch_metrics.namespace,
              local.cloudwatch_metrics.metric_name,
              "ServiceName",
              "continuous-metrics-demo",
              "ClusterName",
              local.name,
              {
                stat   = "SampleCount",
                period = local.dashboard_config.period_seconds
              }
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = "Sum"
          region  = local.region
          title   = "Metrics Count - Continuous Service"
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

      # Service Summary Widget
      {
        type   = "text"
        x      = 0
        y      = 14
        width  = 24
        height = 3
        properties = {
          markdown = "## Continuous Service Summary\n**Service Name**: ${local.name}-continuous-metrics-demo\n**Type**: Always Running (2 instances)\n**Metric**: ${local.cloudwatch_metrics.metric_name}\n**Frequency**: Every ${local.demo_config.metric_generation_interval} seconds\n**Purpose**: Continuous monitoring and metrics generation"
        }
      }
    ]
  })
}

# CloudWatch Dashboard for Scheduled Service Only
resource "aws_cloudwatch_dashboard" "scheduled_service_demo" {
  dashboard_name = "${local.name}-scheduled-service-demo"

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
          markdown = "# Scheduled Service Dashboard\n**Service**: ${local.name}-scheduled-metrics-demo | **Cluster**: ${local.name} | **Type**: Scheduled Execution | **Instances**: 0 (runs when triggered) | **Schedule**: Every 1 minute"
        }
      },

      # Custom ScheduledMetric Widget
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              local.cloudwatch_metrics.namespace,
              "ScheduledMetric",
              "ServiceName",
              "scheduled-metrics-demo",
              "ClusterName", local.name,
              "Type", "Scheduled"
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "Custom ScheduledMetric - Scheduled Service"
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

      # CPU Utilization Widget
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ECS",
              "CPUUtilization",
              "ServiceName",
              "scheduled-metrics-demo",
              "ClusterName",
              local.name
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "CPU Utilization - Scheduled Service"
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

      # Memory Utilization Widget
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "AWS/ECS",
              "MemoryUtilization",
              "ServiceName",
              "scheduled-metrics-demo",
              "ClusterName", local.name,
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = local.dashboard_config.default_stat
          region  = local.region
          title   = "Memory Utilization - Scheduled Service"
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

      # Metrics Count Widget
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              local.cloudwatch_metrics.namespace,
              "ScheduledMetric",
              "ServiceName",
              "scheduled-metrics-demo",
              "ClusterName",
              local.name,
              "Type", "Scheduled",
              {
                stat   = "SampleCount",
                period = local.dashboard_config.period_seconds
              }
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = "Sum"
          region  = local.region
          title   = "Metrics Count - Scheduled Service"
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

      # Task Execution Count Widget
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "ECS/TaskMetrics",
              "ScheduledTaskStarted"
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = "Sum"
          region  = local.region
          title   = "Task Execution Count - Scheduled Service"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = 0
              showUnits = false
              label     = "Execution Count"
            }
          }
        }
      },

      # Task Completion Rate Widget
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "ECS/TaskMetrics",
              "ScheduledTaskCompleted"
            ]
          ]
          period  = local.dashboard_config.period_seconds
          stat    = "Sum"
          region  = local.region
          title   = "Task Completion Count - Scheduled Service"
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min       = 0
              showUnits = false
              label     = "Completion Count"
            }
          }
        }
      },

      # Service Summary Widget
      {
        type   = "text"
        x      = 0
        y      = 20
        width  = 24
        height = 3
        properties = {
          markdown = "## Scheduled Service Summary\n**Service Name**: ${local.name}-scheduled-metrics-demo\n**Type**: Scheduled Execution (runs every 1 minute)\n**Metric**: ScheduledMetric\n**Frequency**: Every 1 minute\n**Purpose**: Periodic data collection and batch processing"
        }
      }
    ]
  })
}

# Outputs
output "continuous_dashboard_url" {
  description = "URL for the Continuous Service Dashboard"
  value       = "https://${data.aws_region.current.region}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.region}#dashboards:name=${aws_cloudwatch_dashboard.continuous_service_demo.dashboard_name}"
}

output "scheduled_dashboard_url" {
  description = "URL for the Scheduled Service Dashboard"
  value       = "https://${data.aws_region.current.region}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.region}#dashboards:name=${aws_cloudwatch_dashboard.scheduled_service_demo.dashboard_name}"
}

output "cluster_info" {
  description = "Information about the ECS cluster and services"
  value = {
    cluster_name = local.name
    region       = local.region
    services = {
      continuous = {
        name        = "continuous-metrics-demo"
        type        = "Always Running"
        instances   = 2
        metric_name = local.cloudwatch_metrics.metric_name
        frequency   = "Every ${local.demo_config.metric_generation_interval} seconds"
      }
      scheduled = {
        name        = "scheduled-metrics-demo"
        type        = "Scheduled"
        instances   = 0
        metric_name = "ScheduledMetric"
        frequency   = "Every 5 minutes"
        schedule    = "rate(5 minutes)"
      }
    }
    dashboards = {
      continuous_service = aws_cloudwatch_dashboard.continuous_service_demo.dashboard_name
      scheduled_service  = aws_cloudwatch_dashboard.scheduled_service_demo.dashboard_name
    }
  }
}
