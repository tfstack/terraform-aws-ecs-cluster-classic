# IAM Role for ECS Instances (One Role for Each ASG)
resource "aws_iam_role" "asg_roles" {
  for_each = { for asg in var.autoscaling_groups : asg.name => asg }

  name = "${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for ECS and ECR Access (One Policy for Each ASG)
resource "aws_iam_policy" "asg_policies" {
  for_each = { for asg in var.autoscaling_groups : asg.name => asg }

  name        = "${each.key}-policy"
  description = "Policy for ECS and ECR Access for ${each.value.name}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeContainerInstances",
          "ecs:DeregisterContainerInstance",
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:ListServices",
          "ecs:ListTagsForResource",
          "ecs:Poll",
          "ecs:RegisterContainerInstance",
          "ecs:StartTelemetrySession",
          "ecs:Submit*",
          "ecs:UpdateContainerInstancesState"
        ],
        Resource = "arn:aws:ecs:*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecs:DiscoverPollEndpoint",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach ECS IAM Policy to Each ASG's Role
resource "aws_iam_role_policy_attachment" "ecs_assume" {
  for_each = aws_iam_role.asg_roles

  policy_arn = lookup(aws_iam_policy.asg_policies, each.key, null).arn
  role       = each.value.name
}

# Attach ECS Agent Registration Policy to Each ASG's Role
resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  for_each = aws_iam_role.asg_roles

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = each.value.name
}

# Attach Additional IAM Policies to Each ASG's Role
resource "aws_iam_role_policy_attachment" "ecs_instance_additional_policy" {
  for_each = {
    for pair in flatten([
      for group in var.autoscaling_groups : [
        for role_key in keys(aws_iam_role.asg_roles) :
        role_key == group.name ? [
          for policy in group.additional_iam_policies : {
            key        = "${role_key}-${policy}"
            role       = aws_iam_role.asg_roles[role_key].name
            policy_arn = policy
          }
        ] : []
      ]
    ]) : pair.key => pair
  }

  role       = each.value.role
  policy_arn = each.value.policy_arn
}


# IAM Instance Profile for Each ASG Role
resource "aws_iam_instance_profile" "ecs_assume" {
  for_each = aws_iam_role.asg_roles
  role     = each.value.name
}

# IAM Role for CloudWatch Agent Task Execution
resource "aws_iam_role" "cwagent_assume" {
  name = "${var.cluster_name}-cwagent-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach CloudWatch Agent Server Policy
resource "aws_iam_role_policy_attachment" "cwagent_cw_server_policy" {
  role       = aws_iam_role.cwagent_assume.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Role for CloudWatch Agent Execution
resource "aws_iam_role" "cwagent_execution" {
  name = "${var.cluster_name}-cwagent-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach Read-Only Access to SSM
resource "aws_iam_role_policy_attachment" "cwagent_ssm_read_policy" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Attach CloudWatch Agent Server Policy
resource "aws_iam_role_policy_attachment" "cwagent_execution_cw" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach ECS Task Execution Policy
resource "aws_iam_role_policy_attachment" "cwagent_execution_ecs" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#########
# Optional ECS Task Execution Role and Policy
resource "aws_iam_role" "ecs_task_execution" {
  for_each = { for s in var.ecs_services : s.name => s if length(s.execution_role_policies) > 0 }

  name = "${each.key}-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach default ECS execution policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  for_each   = aws_iam_role.ecs_task_execution
  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
