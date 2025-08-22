# terraform-aws-ecs-cluster-classic

Terraform module to create a classic EC2-backed ECS cluster with optional CloudWatch agent support

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.10.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.cwagent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_capacity_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster_capacity_providers.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.cwagent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.cwagent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_instance_profile.ecs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.asg_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecs_cloudwatch_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.asg_roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cwagent_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cwagent_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_cloudwatch_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cwagent_cw_server_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_execution_cw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_execution_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_ssm_read_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_cloudwatch_metrics_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_instance_additional_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_instance_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_ssm_parameter.cwagent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instances) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscaling_groups"></a> [autoscaling\_groups](#input\_autoscaling\_groups) | List of Auto Scaling Groups for the ECS cluster | <pre>list(object({<br/>    block_device_mappings = optional(list(object({<br/>      device_name = string<br/>      ebs = object({<br/>        volume_size = number<br/>        volume_type = string<br/>      })<br/>    })), [])<br/><br/>    desired_capacity = number<br/>    ebs_optimized    = bool<br/><br/>    enabled_metrics = optional(list(string), [<br/>      "GroupDesiredCapacity",<br/>      "GroupInServiceCapacity",<br/>      "GroupInServiceInstances",<br/>      "GroupMaxSize",<br/>      "GroupMinSize",<br/>      "GroupPendingCapacity",<br/>      "GroupPendingInstances",<br/>      "GroupStandbyCapacity",<br/>      "GroupStandbyInstances",<br/>      "GroupTerminatingCapacity",<br/>      "GroupTerminatingInstances",<br/>      "GroupTotalCapacity",<br/>      "GroupTotalInstances"<br/>    ])<br/><br/>    image_id                  = string<br/>    health_check_grace_period = optional(number, 0)<br/>    instance_type             = string<br/><br/>    additional_iam_policies = optional(list(string), [])<br/><br/>    instance_refresh = optional(object({<br/>      enabled                      = optional(bool, false)<br/>      strategy                     = optional(string, "Rolling")<br/>      auto_rollback                = optional(bool, false)<br/>      min_healthy_percentage       = optional(number, 75)<br/>      max_healthy_percentage       = optional(number, 100)<br/>      instance_warmup              = optional(number, 300)<br/>      scale_in_protected_instances = optional(string, "Ignore")<br/>      standby_instances            = optional(string, "Ignore")<br/>      skip_matching                = optional(bool, false)<br/>      checkpoint_delay             = optional(number, 3600)<br/>      checkpoint_percentages       = optional(list(number))<br/>      triggers                     = optional(list(string), ["launch_configuration"])<br/>    }), null)<br/><br/>    managed_termination_protection = optional(string, "DISABLED")<br/><br/>    managed_scaling = optional(object({<br/>      status          = string<br/>      target_capacity = number<br/>      }), {<br/>      status          = "ENABLED"<br/>      target_capacity = 100<br/>    })<br/><br/>    max_instance_lifetime = optional(number, 86400)<br/>    max_size              = number<br/><br/>    metadata_options = optional(object({<br/>      http_endpoint               = string<br/>      http_tokens                 = string<br/>      http_put_response_hop_limit = number<br/>      instance_metadata_tags      = string<br/>      }), {<br/>      http_endpoint               = "enabled"<br/>      http_tokens                 = "required"<br/>      http_put_response_hop_limit = 1<br/>      instance_metadata_tags      = "enabled"<br/>    })<br/><br/>    min_size              = number<br/>    name                  = string<br/>    protect_from_scale_in = optional(bool, true)<br/><br/>    tag_specifications = optional(list(object({<br/>      resource_type = string<br/>      tags          = map(string)<br/>    })), [])<br/><br/>    termination_policies = optional(list(string), [<br/>      "AllocationStrategy",<br/>      "OldestLaunchTemplate",<br/>      "ClosestToNextInstanceHour",<br/>      "Default"<br/>    ])<br/><br/>    user_data                            = string<br/>    use_explicit_launch_template_version = optional(bool, false)<br/>  }))</pre> | n/a | yes |
| <a name="input_cloudwatch_agent_config"></a> [cloudwatch\_agent\_config](#input\_cloudwatch\_agent\_config) | CloudWatch Agent configuration. If not provided, uses default configuration. | <pre>object({<br/>    enable_metrics              = optional(bool, true)<br/>    enable_logs                 = optional(bool, true)<br/>    region                      = optional(string, "ap-southeast-2")<br/>    metrics_collection_interval = optional(number, 60)<br/>    logs_collection_interval    = optional(number, 30)<br/>  })</pre> | <pre>{<br/>  "enable_logs": true,<br/>  "enable_metrics": true,<br/>  "logs_collection_interval": 30,<br/>  "metrics_collection_interval": 60,<br/>  "region": "ap-southeast-2"<br/>}</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_container_insights"></a> [container\_insights](#input\_container\_insights) | Enable Container Insights for ECS cluster monitoring | `bool` | `false` | no |
| <a name="input_ecs_services"></a> [ecs\_services](#input\_ecs\_services) | List of ECS services and their task definitions (EC2 launch type only) | <pre>list(object({<br/>    name                    = string<br/>    scheduling_strategy     = optional(string, "REPLICA")<br/>    desired_count           = optional(number, 1)<br/>    cpu                     = optional(string, "256")<br/>    memory                  = optional(string, "512")<br/>    execution_role_policies = optional(list(string), [])<br/>    container_definitions   = string<br/>    enable_ecs_managed_tags = optional(bool, false)<br/>    propagate_tags          = optional(string, "TASK_DEFINITION")<br/><br/>    deployment_minimum_healthy_percent = optional(number, 100)<br/>    deployment_maximum_percent         = optional(number, 200)<br/>    health_check_grace_period_seconds  = optional(number, 0)<br/>    force_new_deployment               = optional(bool, false)<br/>    deployment_controller              = optional(string, "ECS")<br/><br/>    task_role_arn = optional(string)<br/><br/>    network_mode             = optional(string, "bridge")<br/>    requires_compatibilities = optional(list(string), ["EC2"])<br/>    pid_mode                 = optional(string)<br/>    ipc_mode                 = optional(string)<br/><br/>    service_tags = optional(map(string))<br/>    task_tags    = optional(map(string))<br/><br/>    volumes = optional(list(object({<br/>      name      = string<br/>      host_path = string<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_enable_cloudwatch_agent"></a> [enable\_cloudwatch\_agent](#input\_enable\_cloudwatch\_agent) | Enable or disable CloudWatch Agent container | `bool` | `true` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for the provider. Defaults to ap-southeast-2 if not specified. | `string` | `"ap-southeast-2"` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs for ECS instances | `list(string)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration settings | <pre>object({<br/>    id = string<br/>    private_subnets = list(object({<br/>      id   = string<br/>      cidr = string<br/>    }))<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The ARN of the ECS cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the ECS cluster |
| <a name="output_container_insights_enabled"></a> [container\_insights\_enabled](#output\_container\_insights\_enabled) | Whether Container Insights is enabled for the ECS cluster |
| <a name="output_cwagent_execution_role_arn"></a> [cwagent\_execution\_role\_arn](#output\_cwagent\_execution\_role\_arn) | The ARN of the CloudWatch Agent execution role |
| <a name="output_cwagent_service_name"></a> [cwagent\_service\_name](#output\_cwagent\_service\_name) | The name of the CloudWatch Agent ECS Service |
| <a name="output_cwagent_task_definition_arn"></a> [cwagent\_task\_definition\_arn](#output\_cwagent\_task\_definition\_arn) | The ARN of the CloudWatch Agent ECS Task Definition |
| <a name="output_cwagent_task_role_arn"></a> [cwagent\_task\_role\_arn](#output\_cwagent\_task\_role\_arn) | The ARN of the CloudWatch Agent task role |
| <a name="output_ecs_autoscaling_group_arns"></a> [ecs\_autoscaling\_group\_arns](#output\_ecs\_autoscaling\_group\_arns) | ARNs of the ECS Auto Scaling Groups |
| <a name="output_ecs_capacity_providers"></a> [ecs\_capacity\_providers](#output\_ecs\_capacity\_providers) | Names of ECS Capacity Providers |
| <a name="output_ecs_cloudwatch_metrics_role_arn"></a> [ecs\_cloudwatch\_metrics\_role\_arn](#output\_ecs\_cloudwatch\_metrics\_role\_arn) | The ARN of the ECS CloudWatch metrics role for tasks to send custom metrics |
| <a name="output_ecs_cluster_capacity_providers"></a> [ecs\_cluster\_capacity\_providers](#output\_ecs\_cluster\_capacity\_providers) | Capacity providers attached to the ECS cluster |
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | The ECS Cluster ID |
| <a name="output_ecs_custom_services"></a> [ecs\_custom\_services](#output\_ecs\_custom\_services) | ECS Custom Services Information |
| <a name="output_ecs_iam_policy_arns"></a> [ecs\_iam\_policy\_arns](#output\_ecs\_iam\_policy\_arns) | ARNs of the IAM policies for ECS and ECR access |
| <a name="output_ecs_instance_ids"></a> [ecs\_instance\_ids](#output\_ecs\_instance\_ids) | List of ECS Instance IDs in the Auto Scaling Group |
| <a name="output_ecs_instance_private_ips"></a> [ecs\_instance\_private\_ips](#output\_ecs\_instance\_private\_ips) | List of Private IPs of ECS instances in the Auto Scaling Group |
| <a name="output_ecs_instance_profile_names"></a> [ecs\_instance\_profile\_names](#output\_ecs\_instance\_profile\_names) | Names of the ECS instance profiles |
| <a name="output_ecs_instance_role_arns"></a> [ecs\_instance\_role\_arns](#output\_ecs\_instance\_role\_arns) | ARNs of the ECS instance roles |
| <a name="output_ecs_launch_template_ids"></a> [ecs\_launch\_template\_ids](#output\_ecs\_launch\_template\_ids) | IDs of the ECS Launch Templates |
<!-- END_TF_DOCS -->
