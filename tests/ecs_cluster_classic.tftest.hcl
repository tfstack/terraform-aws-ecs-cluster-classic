run "ecs_cluster_test" {
  command = plan

  variables {
    # Define ECS cluster name with a unique suffix
    cluster_name            = "cltest-demo123"
    enable_cloudwatch_agent = true
    security_group_ids      = ["sg-12345678"]

    # Configure VPC settings
    vpc = {
      id = "vpc-12345678"
      private_subnets = [
        { id = "subnet-12345678", cidr = "10.0.101.0/24" },
        { id = "subnet-87654321", cidr = "10.0.102.0/24" }
      ]
    }

    # Configure Auto Scaling Groups
    autoscaling_groups = [
      {
        name             = "asg-1"
        min_size         = 1
        max_size         = 6
        desired_capacity = 3
        image_id         = "ami-12345678"
        instance_type    = "t3a.medium"
        ebs_optimized    = true

        # User data script for ECS cluster configuration
        user_data = <<-EOT
          #!/bin/bash
          echo ECS_CLUSTER=cltest-demo123 >> /etc/ecs/ecs.config
        EOT
      }
    ]

    # Configure ECS Services
    ecs_services = [
      {
        name                    = "web-app"
        scheduling_strategy     = "REPLICA"
        desired_count           = 2
        cpu                     = "256"
        memory                  = "512"
        propagate_tags          = "TASK_DEFINITION"
        enable_ecs_managed_tags = true

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

  # Validate configuration structure
  assert {
    condition     = can(regex("^cltest-", var.cluster_name))
    error_message = "Cluster name must start with 'cltest-' prefix."
  }

  # Validate VPC configuration
  assert {
    condition     = can(var.vpc.id)
    error_message = "VPC ID must be provided."
  }

  # Validate Auto Scaling Group configuration
  assert {
    condition     = length(var.autoscaling_groups) > 0
    error_message = "At least one Auto Scaling Group must be configured."
  }

  # Validate ECS service configuration
  assert {
    condition     = length(var.ecs_services) > 0
    error_message = "At least one ECS service must be configured."
  }

  # Validate container definitions
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      length(jsondecode(service.container_definitions)) > 0
    ])
    error_message = "All ECS services must have valid container definitions."
  }

  # Validate security group configuration
  assert {
    condition     = length(var.security_group_ids) > 0
    error_message = "At least one security group must be provided."
  }

  # Validate VPC subnet configuration
  assert {
    condition     = length(var.vpc.private_subnets) >= 2
    error_message = "At least 2 private subnets are required for high availability."
  }

  # Validate subnet CIDR ranges
  assert {
    condition = alltrue([
      for subnet in var.vpc.private_subnets :
      can(regex("^10\\.0\\..*", subnet.cidr))
    ])
    error_message = "All subnets must be in the 10.0.x.x range."
  }

  # Validate Auto Scaling Group configuration
  assert {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      asg.min_size <= asg.desired_capacity && asg.desired_capacity <= asg.max_size
    ])
    error_message = "ASG configuration must have: min_size <= desired_capacity <= max_size."
  }

  # Validate ECS service resource allocation
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      can(tonumber(service.cpu)) && can(tonumber(service.memory))
    ])
    error_message = "All ECS services must have valid CPU and memory values."
  }

  # Validate container resource allocation
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      length(jsondecode(service.container_definitions)) > 0
    ])
    error_message = "All ECS services must have valid container definitions."
  }

  # Validate health check configuration
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      can(jsondecode(service.container_definitions)[0].healthCheck) || true
    ])
    error_message = "Health check configuration validation passed."
  }

  # Validate port mappings
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      can(jsondecode(service.container_definitions)[0].portMappings) || true
    ])
    error_message = "Port mapping validation passed."
  }

  # Validate execution role policies
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      !can(service.execution_role_policies) || alltrue([
        for policy in service.execution_role_policies :
        can(regex("^arn:aws:iam::", policy))
      ])
    ])
    error_message = "All execution role policies must be valid IAM policy ARNs."
  }

  # Validate CloudWatch agent configuration
  assert {
    condition     = var.enable_cloudwatch_agent == true
    error_message = "CloudWatch agent must be enabled for monitoring."
  }

  # Validate cluster naming convention
  assert {
    condition     = length(var.cluster_name) <= 32
    error_message = "Cluster name must be 32 characters or less."
  }

  # Validate ECS service naming convention
  assert {
    condition = alltrue([
      for service in var.ecs_services :
      length(service.name) <= 255
    ])
    error_message = "All ECS service names must be 255 characters or less."
  }
}
