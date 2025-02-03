
resource "aws_ssm_parameter" "cwagent" {
  name        = "${var.cluster_name}-cwagent-config"
  description = "CloudWatch agent config"
  type        = "String"
  value = jsonencode(
    {
      "agent" : {
        "metrics_collection_interval" : 60
      },
      "logs" : {
        "metrics_collected" : {
          "ecs" : {
            "metrics_collection_interval" : 30
          }
        },
        "logs_collected" : {
          "files" : {
            "collect_list" : [
              {
                "file_path" : "/var/log/ecs/ecs-agent.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-agent",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/ecs-init.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-init",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/audit.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-audit",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/messages",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/messages",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/secure",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/secure",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/auth.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/auth",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/amazon/efs/mount.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/mount.log",
                "timezone" : "UTC"
              }
            ]
          }
        },
        "force_flush_interval" : 15
      }
    }
  )
}
