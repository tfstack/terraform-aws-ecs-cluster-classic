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

    user_data = string
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
    condition     = alltrue([for asg in var.autoscaling_groups : asg.managed_scaling.target_capacity >= 0 && asg.managed_scaling.target_capacity <= 100])
    error_message = "managed_scaling.target_capacity must be between 0 and 100."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.max_instance_lifetime >= 86400 && asg.max_instance_lifetime <= 31536000])
    error_message = "max_instance_lifetime must be between 86,400 (1 day) and 31,536,000 (1 year) seconds."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_endpoint == "enabled"])
    error_message = "metadata_options.http_endpoint must be 'enabled'."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_tokens == "required"])
    error_message = "metadata_options.http_tokens must be 'required'."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : asg.metadata_options.http_put_response_hop_limit >= 1 && asg.metadata_options.http_put_response_hop_limit <= 64])
    error_message = "metadata_options.http_put_response_hop_limit must be between 1 and 64."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : contains(["enabled", "disabled"], asg.metadata_options.instance_metadata_tags)])
    error_message = "metadata_options.instance_metadata_tags must be either 'enabled' or 'disabled'."
  }

  validation {
    condition     = alltrue([for asg in var.autoscaling_groups : alltrue([for policy in asg.termination_policies : contains(["AllocationStrategy", "OldestLaunchTemplate", "ClosestToNextInstanceHour", "Default"], policy)])])
    error_message = "termination_policies must contain only valid values: 'AllocationStrategy', 'OldestLaunchTemplate', 'ClosestToNextInstanceHour', or 'Default'."
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

variable "ecs_services" {
  description = "List of ECS services and their task definitions"
  type = list(object({
    name                    = string
    scheduling_strategy     = optional(string, "REPLICA")
    desired_count           = optional(number, 1)
    cpu                     = optional(string, "256")
    memory                  = optional(string, "512")
    execution_role_policies = optional(list(string), [])
    container_definitions   = string
    enable_ecs_managed_tags = optional(bool, false)

    service_tags = optional(map(string))
    task_tags    = optional(map(string))

    volumes = optional(list(object({
      name      = string
      host_path = string
    })), [])
  }))
  default = []
}
