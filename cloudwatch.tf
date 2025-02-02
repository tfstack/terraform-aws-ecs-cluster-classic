# Log group for Cloudwatch Agent
resource "aws_cloudwatch_log_group" "cwagent" {
  name              = "/ecs/${var.cluster_name}/cwagent"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}
