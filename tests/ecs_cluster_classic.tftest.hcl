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
}
