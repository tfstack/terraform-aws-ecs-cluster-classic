# terraform-aws-ecs-cluster-classic

Terraform module to create a classic EC2-backed ECS cluster with optional CloudWatch agent support

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

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
| [aws_iam_policy.ecs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cwagent_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cwagent_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cwagent_cw_server_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_execution_cw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_execution_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cwagent_ssm_read_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_instance_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_ssm_parameter.cwagent](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_autoscaling_groups"></a> [autoscaling\_groups](#input\_autoscaling\_groups) | List of Auto Scaling Groups for the ECS cluster | <pre>list(object({<br/>  block_device_mappings = optional(list(object({<br/>    device_name = string<br/>    ebs = object({<br/>      volume_size = number<br/>      volume_type = string<br/>    })<br/>  })), [])<br/><br/>  desired_capacity = number<br/>  ebs_optimized    = bool<br/><br/>  enabled_metrics = optional(list(string), [<br/>    "GroupDesiredCapacity",<br/>    "GroupInServiceCapacity",<br/>    "GroupInServiceInstances",<br/>    "GroupMaxSize",<br/>    "GroupMinSize",<br/>    "GroupPendingCapacity",<br/>    "GroupPendingInstances",<br/>    "GroupStandbyCapacity",<br/>    "GroupStandbyInstances",<br/>    "GroupTerminatingCapacity",<br/>    "GroupTerminatingInstances",<br/>    "GroupTotalCapacity",<br/>    "GroupTotalInstances"<br/>  ])<br/><br/>  image_id                  = string<br/>  health_check_grace_period = optional(number, 0)<br/>  instance_type             = string<br/><br/>  managed_scaling = optional(object({<br/>    status          = string<br/>    target_capacity = number<br/>  }), {<br/>    status          = "ENABLED"<br/>    target_capacity = 100<br/>  })<br/><br/>  max_instance_lifetime = optional(number, 86400)<br/>  max_size              = number<br/><br/>  metadata_options = optional(object({<br/>    http_endpoint               = string<br/>    http_tokens                 = string<br/>    http_put_response_hop_limit = number<br/>    instance_metadata_tags      = string<br/>  }), {<br/>    http_endpoint               = "enabled"<br/>    http_tokens                 = "required"<br/>    http_put_response_hop_limit = 1<br/>    instance_metadata_tags      = "enabled"<br/>  })<br/><br/>  min_size              = number<br/>  name                  = string<br/>  protect_from_scale_in = optional(bool, true)<br/><br/>  tag_specifications = optional(list(object({<br/>    resource_type = string<br/>    tags          = map(string)<br/>  })), [])<br/><br/>  termination_policies = optional(list(string), [<br/>    "AllocationStrategy",<br/>    "OldestLaunchTemplate",<br/>    "ClosestToNextInstanceHour",<br/>    "Default"<br/>  ])<br/><br/>  user_data = string<br/>}))</pre> | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ECS cluster | `string` | n/a | yes |
| <a name="input_ecs_services"></a> [ecs\_services](#input\_ecs\_services) | List of ECS services and their task definitions | <pre>list(object({<br/>  name                    = string<br/>  scheduling_strategy     = optional(string, "REPLICA")<br/>  desired_count           = optional(number, 1)<br/>  cpu                     = optional(string, "256")<br/>  memory                  = optional(string, "512")<br/>  execution_role_policies = optional(list(string), [])<br/>  container_definitions   = string<br/>  enable_ecs_managed_tags = optional(bool, false)<br/><br/>  service_tags = optional(map(string))<br/>  task_tags    = optional(map(string))<br/><br/>  volumes = optional(list(object({<br/>    name      = string<br/>    host_path = string<br/>  })), [])<br/>}))</pre> | `[]` | no |
| <a name="input_enable_cloudwatch_agent"></a> [enable\_cloudwatch\_agent](#input\_enable\_cloudwatch\_agent) | Enable or disable CloudWatch Agent container | `bool` | `true` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | List of security group IDs for ECS instances | `list(string)` | `[]` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configuration settings | <pre>object({<br/>  id = string<br/>  private_subnets = list(object({<br/>    id   = string<br/>    cidr = string<br/>  }))<br/>})</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cwagent_execution_role_arn"></a> [cwagent\_execution\_role\_arn](#output\_cwagent\_execution\_role\_arn) | The ARN of the CloudWatch Agent execution role |
| <a name="output_cwagent_service_name"></a> [cwagent\_service\_name](#output\_cwagent\_service\_name) | The name of the CloudWatch Agent ECS Service |
| <a name="output_cwagent_task_definition_arn"></a> [cwagent\_task\_definition\_arn](#output\_cwagent\_task\_definition\_arn) | The ARN of the CloudWatch Agent ECS Task Definition |
| <a name="output_cwagent_task_role_arn"></a> [cwagent\_task\_role\_arn](#output\_cwagent\_task\_role\_arn) | The ARN of the CloudWatch Agent task role |
| <a name="output_ecs_autoscaling_group_arns"></a> [ecs\_autoscaling\_group\_arns](#output\_ecs\_autoscaling\_group\_arns) | ARNs of the ECS Auto Scaling Groups |
| <a name="output_ecs_capacity_providers"></a> [ecs\_capacity\_providers](#output\_ecs\_capacity\_providers) | Names of ECS Capacity Providers |
| <a name="output_ecs_cluster_capacity_providers"></a> [ecs\_cluster\_capacity\_providers](#output\_ecs\_cluster\_capacity\_providers) | Capacity providers attached to the ECS cluster |
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | The ECS Cluster ID |
| <a name="output_ecs_custom_services"></a> [ecs\_custom\_services](#output\_ecs\_custom\_services) | ECS Custom Services Information |
| <a name="output_ecs_iam_policy_arn"></a> [ecs\_iam\_policy\_arn](#output\_ecs\_iam\_policy\_arn) | The ARN of the IAM policy for ECS and ECR access |
| <a name="output_ecs_instance_profile_name"></a> [ecs\_instance\_profile\_name](#output\_ecs\_instance\_profile\_name) | The name of the ECS instance profile |
| <a name="output_ecs_instance_role_arn"></a> [ecs\_instance\_role\_arn](#output\_ecs\_instance\_role\_arn) | The ARN of the ECS instance role |
| <a name="output_ecs_launch_template_ids"></a> [ecs\_launch\_template\_ids](#output\_ecs\_launch\_template\_ids) | IDs of the ECS Launch Templates |
