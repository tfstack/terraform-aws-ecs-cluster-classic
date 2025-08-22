variable "region" {
  description = "AWS region for the provider. Defaults to ap-southeast-2 if not specified."
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]+-\\d{1})$", var.region))
    error_message = "Invalid AWS region format. Example: 'us-east-1', 'ap-southeast-2'."
  }
}

variable "vpc" {
  description = "VPC configuration settings"
  type = object({
    id = string
    private_subnets = list(object({
      id   = string
      cidr = string
    }))
  })

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc.id))
    error_message = "The VPC ID must be in the format 'vpc-xxxxxxxxxxxxxxxxx'."
  }

  validation {
    condition     = length(var.vpc.private_subnets) > 0
    error_message = "At least one private subnet must be defined."
  }

  validation {
    condition     = alltrue([for subnet in var.vpc.private_subnets : can(regex("^subnet-[a-f0-9]+$", subnet.id))])
    error_message = "Each private subnet must have a valid subnet ID (e.g., 'subnet-xxxxxxxxxxxxxxxxx')."
  }

  validation {
    condition     = alltrue([for subnet in var.vpc.private_subnets : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", subnet.cidr))])
    error_message = "Each subnet must have a valid CIDR block (e.g., '10.0.1.0/24')."
  }
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs for ECS instances"
  type        = list(string)
  default     = []
}

variable "autoscaling_groups" {
  description = "List of Auto Scaling Groups for the ECS cluster"
  type = list(object({
    block_device_mappings = optional(list(object({
      device_name = string
      ebs = object({
        volume_size = number
        volume_type = string
      })
    })), [])

    desired_capacity = number
    ebs_optimized    = bool

    enabled_metrics = optional(list(string), [
      "GroupDesiredCapacity",
      "GroupInServiceCapacity",
      "GroupInServiceInstances",
      "GroupMaxSize",
      "GroupMinSize",
      "GroupPendingCapacity",
      "GroupPendingInstances",
      "GroupStandbyCapacity",
      "GroupStandbyInstances",
      "GroupTerminatingCapacity",
      "GroupTerminatingInstances",
      "GroupTotalCapacity",
      "GroupTotalInstances"
    ])

    image_id                  = string
    health_check_grace_period = optional(number, 0)
    instance_type             = string

    additional_iam_policies = optional(list(string), [])

    instance_refresh = optional(object({
      enabled                      = optional(bool, false)
      strategy                     = optional(string, "Rolling")
      auto_rollback                = optional(bool, false)
      min_healthy_percentage       = optional(number, 75)
      max_healthy_percentage       = optional(number, 100)
      instance_warmup              = optional(number, 300)
      scale_in_protected_instances = optional(string, "Ignore")
      standby_instances            = optional(string, "Ignore")
      skip_matching                = optional(bool, false)
      checkpoint_delay             = optional(number, 3600)
      checkpoint_percentages       = optional(list(number))
      triggers                     = optional(list(string), ["launch_configuration"])
    }), null)

    managed_termination_protection = optional(string, "DISABLED")

    managed_scaling = optional(object({
      status          = string
      target_capacity = number
      }), {
      status          = "ENABLED"
      target_capacity = 100
    })

    max_instance_lifetime = optional(number, 86400)
    max_size              = number

    metadata_options = optional(object({
      http_endpoint               = string
      http_tokens                 = string
      http_put_response_hop_limit = number
      instance_metadata_tags      = string
      }), {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 1
      instance_metadata_tags      = "enabled"
    })

    min_size              = number
    name                  = string
    protect_from_scale_in = optional(bool, true)

    tag_specifications = optional(list(object({
      resource_type = string
      tags          = map(string)
    })), [])

    termination_policies = optional(list(string), [
      "AllocationStrategy",
      "OldestLaunchTemplate",
      "ClosestToNextInstanceHour",
      "Default"
    ])

    user_data                            = string
    use_explicit_launch_template_version = optional(bool, false)
  }))

  validation {
    condition     = length(var.autoscaling_groups) > 0
    error_message = "At least one Auto Scaling Group must be defined."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.min_size >= 0])
    error_message = "min_size must be greater than or equal to 0."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.max_size >= asg.min_size])
    error_message = "max_size must be greater than or equal to min_size."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.desired_capacity >= asg.min_size && asg.desired_capacity <= asg.max_size])
    error_message = "desired_capacity must be between min_size and max_size."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : can(regex("^ami-[a-f0-9]+$", asg.image_id))])
    error_message = "Each image_id must be a valid AWS AMI ID (e.g., 'ami-xxxxxxxxxxxxxxxxx')."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(contains(["Rolling"], asg.instance_refresh.strategy), true) # Use `try()` to avoid accessing null
    ])
    error_message = "Only Rolling is allowed as an instance refresh strategy."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(!asg.instance_refresh.auto_rollback || contains(["launch_configuration", "launch_template"], asg.instance_refresh.triggers[0]), true)
    ])
    error_message = "auto_rollback may only be set to true when specifying a launch_template or launch_configuration."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(asg.instance_refresh.min_healthy_percentage >= 0 && asg.instance_refresh.min_healthy_percentage <= 100, true)
    ])
    error_message = "min_healthy_percentage must be between 0 and 100."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(asg.instance_refresh.max_healthy_percentage >= 100 && asg.instance_refresh.max_healthy_percentage <= 200, true)
    ])
    error_message = "max_healthy_percentage must be between 100 and 200."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(contains(["Refresh", "Ignore", "Wait"], asg.instance_refresh.scale_in_protected_instances), true)
    ])
    error_message = "scale_in_protected_instances must be one of: Refresh, Ignore, or Wait."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(asg.instance_refresh.instance_warmup >= 0, true)
    ])
    error_message = "instance_warmup must be a non-negative integer (>= 0)."
  }

  validation {
    condition = alltrue([
      for asg in var.autoscaling_groups :
      try(contains(["Terminate", "Ignore", "Wait"], asg.instance_refresh.standby_instances), true)
    ])
    error_message = "standby_instances must be one of: Terminate, Ignore, or Wait."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : contains(["ENABLED", "DISABLED"], asg.managed_termination_protection)])
    error_message = "Allowed values for managed_termination_protection are ENABLED or DISABLED."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.managed_scaling.target_capacity >= 0 && asg.managed_scaling.target_capacity <= 100])
    error_message = "managed_scaling.target_capacity must be between 0 and 100."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.max_instance_lifetime >= 86400 && asg.max_instance_lifetime <= 31536000])
    error_message = "max_instance_lifetime must be between 86,400 (1 day) and 31,536,000 (1 year) seconds."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_endpoint == "enabled"])
    error_message = "metadata_options.http_endpoint must be enabled."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_tokens == "required"])
    error_message = "metadata_options.http_tokens must be required."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_put_response_hop_limit >= 1 && asg.metadata_options.http_put_response_hop_limit <= 64])
    error_message = "metadata_options.http_put_response_hop_limit must be between 1 and 64."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : contains(["enabled", "disabled"], asg.metadata_options.instance_metadata_tags)])
    error_message = "metadata_options.instance_metadata_tags must be either enabled or disabled."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : alltrue([for policy in asg.termination_policies : contains(["AllocationStrategy", "OldestLaunchTemplate", "ClosestToNextInstanceHour", "Default"], policy)])])
    error_message = "termination_policies must contain only valid values: AllocationStrategy, OldestLaunchTemplate, ClosestToNextInstanceHour, or Default."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : alltrue([for policy in asg.additional_iam_policies : can(regex("^arn:aws:iam:", policy))])])
    error_message = "Each IAM policy in additional_iam_policies must be a valid AWS IAM policy ARN (e.g., 'arn:aws:iam::123456789012:policy/YourPolicyName')."
  }
}
variable "enable_cloudwatch_agent" {
  description = "Enable or disable CloudWatch Agent container"
  type        = bool
  default     = true
}

variable "cloudwatch_agent_config" {
  description = "CloudWatch Agent configuration. If not provided, uses default configuration."
  type = object({
    enable_metrics              = optional(bool, true)
    enable_logs                 = optional(bool, true)
    region                      = optional(string, "ap-southeast-2")
    metrics_collection_interval = optional(number, 60)
    logs_collection_interval    = optional(number, 30)
  })
  default = {
    enable_metrics              = true
    enable_logs                 = true
    region                      = "ap-southeast-2"
    metrics_collection_interval = 60
    logs_collection_interval    = 30
  }
}

variable "container_insights" {
  description = "Enable Container Insights for ECS cluster monitoring"
  type        = bool
  default     = false
}

variable "ecs_services" {
  description = "List of ECS services and their task definitions (EC2 launch type only)"
  type = list(object({
    name                    = string
    scheduling_strategy     = optional(string, "REPLICA")
    desired_count           = optional(number, 1)
    cpu                     = optional(string, "256")
    memory                  = optional(string, "512")
    execution_role_policies = optional(list(string), [])
    container_definitions   = string
    enable_ecs_managed_tags = optional(bool, false)
    propagate_tags          = optional(string, "TASK_DEFINITION")

    deployment_minimum_healthy_percent = optional(number, 100)
    deployment_maximum_percent         = optional(number, 200)
    health_check_grace_period_seconds  = optional(number, 0)
    force_new_deployment               = optional(bool, false)
    deployment_controller              = optional(string, "ECS")

    task_role_arn = optional(string)

    network_mode             = optional(string, "bridge")
    requires_compatibilities = optional(list(string), ["EC2"])
    pid_mode                 = optional(string)
    ipc_mode                 = optional(string)

    service_tags = optional(map(string))
    task_tags    = optional(map(string))

    volumes = optional(list(object({
      name      = string
      host_path = string
    })), [])
  }))

  default = []

  validation {
    condition     = alltrue([for s in var.ecs_services : contains(["REPLICA", "DAEMON"], s.scheduling_strategy)])
    error_message = "scheduling_strategy must be either REPLICA or DAEMON."
  }

  validation {
    condition     = alltrue([for s in var.ecs_services : contains(["bridge", "host"], s.network_mode)])
    error_message = "network_mode must be bridge or host (EC2 only, no awsvpc)."
  }

  validation {
    condition     = alltrue([for s in var.ecs_services : contains(["ECS", "CODE_DEPLOY"], s.deployment_controller)])
    error_message = "deployment_controller must be ECS or CODE_DEPLOY."
  }

  validation {
    condition     = alltrue([for s in var.ecs_services : can(regex("^[0-9]+$", s.cpu))])
    error_message = "cpu must be a numeric string (e.g., 256, 512, 1024)."
  }

  validation {
    condition     = alltrue([for s in var.ecs_services : can(regex("^[0-9]+$", s.memory))])
    error_message = "memory must be a numeric string (e.g., 512, 1024, 2048)."
  }
}
