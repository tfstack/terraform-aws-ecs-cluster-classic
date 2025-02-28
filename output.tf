# CloudWatch Agent Outputs
output "cwagent_execution_role_arn" {
  description = "The ARN of the CloudWatch Agent execution role"
  value       = aws_iam_role.cwagent_execution.arn
}

output "cwagent_service_name" {
  description = "The name of the CloudWatch Agent ECS Service"
  value       = length(aws_ecs_service.cwagent) > 0 ? aws_ecs_service.cwagent[0].name : null
}

output "cwagent_task_definition_arn" {
  description = "The ARN of the CloudWatch Agent ECS Task Definition"
  value       = length(aws_ecs_task_definition.cwagent) > 0 ? aws_ecs_task_definition.cwagent[0].arn : null
}

output "cwagent_task_role_arn" {
  description = "The ARN of the CloudWatch Agent task role"
  value       = aws_iam_role.cwagent_assume.arn
}

# Custom services Outputs
output "ecs_custom_services" {
  description = "ECS Custom Services Information"
  value = {
    for k, v in aws_ecs_service.this : k => {
      service_name       = v.name
      task_definition    = aws_ecs_task_definition.this[k].arn
      execution_role_arn = try(aws_iam_role.ecs_task_execution[k].arn, null)
    }
  }
}

# ECS Cluster Outputs
output "ecs_autoscaling_group_arns" {
  description = "ARNs of the ECS Auto Scaling Groups"
  value       = { for k, v in aws_autoscaling_group.this : k => v.arn }
}

output "ecs_capacity_providers" {
  description = "Names of ECS Capacity Providers"
  value       = { for k, v in aws_ecs_capacity_provider.this : k => v.name }
}

output "ecs_cluster_capacity_providers" {
  description = "Capacity providers attached to the ECS cluster"
  value       = aws_ecs_cluster_capacity_providers.this.capacity_providers
}

output "ecs_cluster_id" {
  description = "The ECS Cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "ecs_instance_ids" {
  description = "List of ECS Instance IDs in the Auto Scaling Group"
  value       = data.aws_instances.this.ids
}

output "ecs_instance_private_ips" {
  description = "List of Private IPs of ECS instances in the Auto Scaling Group"
  value       = data.aws_instances.this.private_ips
}

output "ecs_launch_template_ids" {
  description = "IDs of the ECS Launch Templates"
  value       = { for k, v in aws_launch_template.this : k => v.id }
}

# ECS IAM Outputs
output "ecs_iam_policy_arns" {
  description = "ARNs of the IAM policies for ECS and ECR access"
  value       = { for k, v in aws_iam_policy.asg_policies : k => v.arn }
}

output "ecs_instance_profile_names" {
  description = "Names of the ECS instance profiles"
  value       = { for k, v in aws_iam_instance_profile.ecs_assume : k => v.name }
}

output "ecs_instance_role_arns" {
  description = "ARNs of the ECS instance roles"
  value       = { for k, v in aws_iam_role.asg_roles : k => v.arn }
}
