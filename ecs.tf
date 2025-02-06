resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

## Cloudwatch Agent
resource "aws_ecs_task_definition" "cwagent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  family                   = "${var.cluster_name}-cwagent"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  task_role_arn            = aws_iam_role.cwagent_assume.arn
  execution_role_arn       = aws_iam_role.cwagent_execution.arn

  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "dev"
    host_path = "/dev"
  }

  volume {
    name      = "host_logs"
    host_path = "/var/log"
  }

  volume {
    name      = "al1_cgroup"
    host_path = "/cgroup"
  }

  volume {
    name      = "al2_cgroup"
    host_path = "/sys/fs/cgroup"
  }

  container_definitions = jsonencode([
    {
      name      = "cwagent"
      image     = "amazon/cloudwatch-agent:latest"
      essential = true
      memory    = 256
      cpu       = 128

      mountPoints = [
        {
          readOnly      = true
          containerPath = "/rootfs/proc"
          sourceVolume  = "proc"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/dev"
          sourceVolume  = "dev"
        },
        {
          readOnly      = true
          containerPath = "/sys/fs/cgroup"
          sourceVolume  = "al2_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/cgroup"
          sourceVolume  = "al1_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/sys/fs/cgroup"
          sourceVolume  = "al2_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/rootfs/cgroup"
          sourceVolume  = "al1_cgroup"
        },
        {
          readOnly      = true
          containerPath = "/var/log"
          sourceVolume  = "host_logs"
        }
      ]

      secrets = [
        {
          name      = "CW_CONFIG_CONTENT"
          valueFrom = "${aws_ssm_parameter.cwagent.name}"
        }
      ]

      healthCheck = {
        command  = ["CMD", "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent", "--version"]
        interval = 30
        timeout  = 5
        retries  = 3
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.cluster_name}/cwagent"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "cwagent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name                = "${var.cluster_name}-cwagent"
  cluster             = aws_ecs_cluster.this.id
  task_definition     = aws_ecs_task_definition.cwagent[0].arn
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "DAEMON"

  enable_ecs_managed_tags = true

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_cloudwatch_log_group.cwagent
  ]
}

## Custom services
resource "aws_ecs_task_definition" "this" {
  for_each = { for s in var.ecs_services : s.name => s }

  family                   = each.value.name
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory

  execution_role_arn    = length(each.value.execution_role_policies) > 0 ? aws_iam_role.ecs_task_execution[each.key].arn : null
  container_definitions = each.value.container_definitions

  dynamic "volume" {
    for_each = lookup(each.value, "volumes", [])

    content {
      name      = try(volume.value.name, volume.key)
      host_path = try(volume.value.host_path, null)
    }
  }
}

resource "aws_ecs_service" "this" {
  for_each = { for s in var.ecs_services : s.name => s }

  name                 = each.value.name
  cluster              = aws_ecs_cluster.this.id
  task_definition      = aws_ecs_task_definition.this[each.key].arn
  launch_type          = "EC2"
  force_new_deployment = true

  scheduling_strategy = lookup(each.value, "scheduling_strategy", "REPLICA")
  propagate_tags      = lookup(each.value, "propagate_tags", null)

  desired_count = lookup(each.value, "scheduling_strategy", "REPLICA") == "REPLICA" ? lookup(each.value, "desired_count", 1) : null
}
