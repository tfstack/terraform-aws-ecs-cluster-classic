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

variable "dd_api_key" {
  description = "Datadog API key used for installing and configuring the Datadog Agent."
  type        = string
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

resource "aws_cloudwatch_log_group" "wildfly" {
  name              = "/ecs/${local.name}/wildfly"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "ddagent" {
  name              = "/ecs/${local.name}/ddagent"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
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
    },
    {
      name          = "wildfly"
      desired_count = 2
      cpu           = "512"
      memory        = "1024"

      execution_role_policies = [
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]

      container_definitions = jsonencode([
        {
          name      = "wildfly"
          image     = "jboss/wildfly"
          cpu       = 512
          memory    = 1024
          essential = true

          portMappings = [
            {
              containerPort = 8080
              hostPort      = 0
              protocol      = "tcp"
            },
            {
              containerPort = 9990
              hostPort      = 0
              protocol      = "tcp"
            }
          ]

          healthCheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:8080 || exit 1"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 20
          }

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/${local.name}/wildfly"
              awslogs-region        = local.region
              awslogs-stream-prefix = "ecs"
            }
          }
        }
      ])
    },
    {
      name                = "ddagent"
      scheduling_strategy = "DAEMON"
      cpu                 = "128"
      memory              = "256"

      execution_role_policies = [
        "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
      ]

      container_definitions = jsonencode([
        {
          name      = "datadog-agent"
          image     = "public.ecr.aws/datadog/agent:latest"
          cpu       = 128
          memory    = 256
          essential = true

          mountPoints = [
            { containerPath = "/etc/passwd", sourceVolume = "passwd", readOnly = true },
            { containerPath = "/var/run/docker.sock", sourceVolume = "docker_sock", readOnly = true },
            { containerPath = "/host/sys/fs/cgroup", sourceVolume = "cgroup", readOnly = true },
            { containerPath = "/host/proc/", sourceVolume = "proc", readOnly = true },
            { containerPath = "/sys/kernel/debug", sourceVolume = "debug" },
            { containerPath = "/host/etc/os-release", sourceVolume = "os_release", readOnly = true },
            { containerPath = "/etc/group", sourceVolume = "group", readOnly = true }
          ]

          environment = [
            { name = "DD_API_KEY", value = var.dd_api_key },
            { name = "DD_SITE", value = "datadoghq.com" },
            { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
            { name = "DD_ECS_COLLECT_RESOURCE_TAGS_EC2", value = "true" },
            { name = "DD_SYSTEM_PROBE_NETWORK_ENABLED", value = "true" },
            { name = "DD_TRACEROUTE_ENABLED", value = "true" },
            { name = "DD_NETWORK_PATH_CONNECTIONS_MONITORING_ENABLED", value = "true" }
          ]

          healthCheck = {
            command     = ["CMD-SHELL", "agent health"]
            interval    = 30
            timeout     = 5
            retries     = 3
            startPeriod = 15
          }

          linuxParameters = {
            capabilities = {
              add = [
                "NET_ADMIN",
                "NET_RAW",
                "SYS_ADMIN",
                "SYS_RESOURCE",
                "SYS_PTRACE",
                "NET_BROADCAST",
                "IPC_LOCK",
                "CHOWN"
              ]
              drop = []
            }
          }

          logConfiguration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/ecs/${local.name}/ddagent"
              awslogs-region        = local.region
              awslogs-stream-prefix = "ecs"
            }
          }
        }
      ])

      volumes = [
        { name = "passwd", host_path = "/etc/passwd" },
        { name = "proc", host_path = "/proc/" },
        { name = "docker_sock", host_path = "/var/run/docker.sock" },
        { name = "cgroup", host_path = "/sys/fs/cgroup/" },
        { name = "debug", host_path = "/sys/kernel/debug" },
        { name = "os_release", host_path = "/etc/os-release" },
        { name = "group", host_path = "/etc/group" }
      ]
    }
  ]

  depends_on = [
    aws_cloudwatch_log_group.wildfly,
    aws_cloudwatch_log_group.ddagent
  ]
}

# Outputs
output "all_module_outputs" {
  description = "All outputs from the ECS module"
  value       = module.ecs_cluster_classic
}
