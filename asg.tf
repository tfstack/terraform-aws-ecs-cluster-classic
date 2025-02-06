resource "aws_launch_template" "this" {
  for_each = { for asg in var.autoscaling_groups : asg.name => asg }

  name_prefix   = "${var.cluster_name}-${each.value.name}"
  image_id      = each.value.image_id
  ebs_optimized = each.value.ebs_optimized
  instance_type = each.value.instance_type

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_assume.name
  }

  metadata_options {
    http_endpoint               = each.value.metadata_options.http_endpoint
    http_tokens                 = each.value.metadata_options.http_tokens
    http_put_response_hop_limit = each.value.metadata_options.http_put_response_hop_limit
    instance_metadata_tags      = each.value.metadata_options.instance_metadata_tags
  }

  dynamic "block_device_mappings" {
    for_each = each.value.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        volume_size = block_device_mappings.value.ebs.volume_size
        volume_type = block_device_mappings.value.ebs.volume_type
      }
    }
  }

  dynamic "tag_specifications" {
    for_each = each.value.tag_specifications
    content {
      resource_type = tag_specifications.value.resource_type
      tags          = tag_specifications.value.tags
    }
  }

  user_data = base64encode(each.value.user_data)
}

resource "aws_autoscaling_group" "this" {
  for_each = { for asg in var.autoscaling_groups : asg.name => asg }

  name                = "${var.cluster_name}-${each.value.name}"
  vpc_zone_identifier = [for subnet in var.vpc.private_subnets : subnet.id]

  max_size                  = each.value.max_size
  min_size                  = each.value.min_size
  desired_capacity          = each.value.desired_capacity
  health_check_type         = "EC2"
  health_check_grace_period = each.value.health_check_grace_period

  enabled_metrics       = each.value.enabled_metrics
  termination_policies  = each.value.termination_policies
  protect_from_scale_in = each.value.protect_from_scale_in
  max_instance_lifetime = each.value.max_instance_lifetime

  launch_template {
    name    = aws_launch_template.this[each.key].name
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity,
      tag
    ]
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-${each.value.name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  for_each = { for asg in var.autoscaling_groups : asg.name => asg }

  name = "${var.cluster_name}-${each.value.name}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this[each.key].arn

    managed_scaling {
      status          = each.value.managed_scaling.status
      target_capacity = each.value.managed_scaling.target_capacity
    }
  }

  depends_on = [aws_autoscaling_group.this]
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [for asg in var.autoscaling_groups : "${var.cluster_name}-${asg.name}"]

  lifecycle {
    ignore_changes = [capacity_providers] # Prevent destruction dependency issues
  }

  depends_on = [
    aws_ecs_capacity_provider.this
  ]
}
