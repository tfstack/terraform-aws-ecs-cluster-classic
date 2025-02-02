# IAM Role for ECS Instances
resource "aws_iam_role" "ecs_assume" {
  name = "${var.cluster_name}-ecs-assume"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for ECS and ECR Access
resource "aws_iam_policy" "ecs_assume" {
  name        = "${var.cluster_name}-ecs-assume"
  description = "Policy for ECS and ECR"

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

# Attach ECS IAM Policy to Role
resource "aws_iam_role_policy_attachment" "ecs_assume" {
  policy_arn = aws_iam_policy.ecs_assume.arn
  role       = aws_iam_role.ecs_assume.name
}

# Attach ECS Agent Registration Policy
# This allows EC2 instances to register with an ECS Cluster
resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.ecs_assume.name
}

# IAM Instance Profile for ECS Role
resource "aws_iam_instance_profile" "ecs_assume" {
  name = "${var.cluster_name}-ecs-assume"
  role = aws_iam_role.ecs_assume.name
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
