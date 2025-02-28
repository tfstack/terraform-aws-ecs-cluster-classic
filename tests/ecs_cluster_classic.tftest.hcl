run "setup_ecs" {
  module {
    source = "./tests/setup"
  }
}

run "ecs_cluster_test" {
  variables {
    # Define ECS cluster name with a unique suffix
    cluster_name            = "cltest-${run.setup_ecs.suffix}"
    enable_cloudwatch_agent = true
    security_group_ids      = [run.setup_ecs.security_group_id]

    # Configure VPC settings
    vpc = {
      id = run.setup_ecs.vpc_id
      private_subnets = [
        for i, subnet in run.setup_ecs.private_subnets :
        { id = subnet, cidr = run.setup_ecs.private_subnets_cidr_blocks[i] }
      ]
    }

    # Configure Auto Scaling Groups
    autoscaling_groups = [
      {
        name             = "asg-1"
        min_size         = 1
        max_size         = 6
        desired_capacity = 3
        image_id         = run.setup_ecs.image_id
        instance_type    = "t3a.medium"
        ebs_optimized    = true

        # User data script for ECS cluster configuration
        user_data = <<-EOT
          #!/bin/bash
          echo ECS_CLUSTER=cltest-${run.setup_ecs.suffix} >> /etc/ecs/ecs.config
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

  # Validate ECS cluster creation
  assert {
    condition     = length(aws_ecs_cluster.this) > 0
    error_message = "ECS Cluster was not created successfully."
  }

  # Validate Auto Scaling Group creation
  assert {
    condition     = length(aws_autoscaling_group.this) > 0
    error_message = "Auto Scaling Group was not created successfully."
  }

  # Validate ECS instances exist
  assert {
    condition = alltrue([
      for id in data.aws_instances.this.ids : can(id)
    ])
    error_message = "No valid ECS instance IDs found."
  }

  # Ensure all private IPs are within the expected VPC CIDR range
  assert {
    condition = alltrue([
      for ip in data.aws_instances.this.private_ips : can(regex("^10\\.0\\..*", ip))
    ])
    error_message = "Some ECS instance private IPs are outside the expected VPC CIDR range."
  }

  # Validate ECS services exist
  assert {
    condition = alltrue([
      for s in keys(aws_ecs_service.this) : can(s)
    ])
    error_message = "ECS Services were not created successfully."
  }
}
