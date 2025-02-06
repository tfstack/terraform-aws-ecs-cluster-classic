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

output "ecs_launch_template_ids" {
  description = "IDs of the ECS Launch Templates"
  value       = { for k, v in aws_launch_template.this : k => v.id }
}

# ECS IAM Outputs
output "ecs_iam_policy_arn" {
  description = "The ARN of the IAM policy for ECS and ECR access"
  value       = aws_iam_policy.ecs_assume.arn
}

output "ecs_instance_profile_name" {
  description = "The name of the ECS instance profile"
  value       = aws_iam_instance_profile.ecs_assume.name
}

output "ecs_instance_role_arn" {
  description = "The ARN of the ECS instance role"
  value       = aws_iam_role.ecs_assume.arn
}
