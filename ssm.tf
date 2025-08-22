
resource "aws_ssm_parameter" "cwagent" {
  name        = "${var.cluster_name}-cwagent-config"
  description = "CloudWatch agent config"
  type        = "String"
  value = jsonencode(
    merge(
      {
        "agent" : {
          "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval,
          "region" : var.cloudwatch_agent_config.region
        }
      },
      var.cloudwatch_agent_config.enable_metrics ? {
        "metrics" : {
          "metrics_collected" : {
            "ecs" : {
              "measurement" : ["ecs_running_task_count", "ecs_pending_task_count"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval,
              "resources" : ["*"]
            },
            "cpu" : {
              "measurement" : ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval,
              "totalcpu" : false
            },
            "disk" : {
              "measurement" : ["used_percent"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval,
              "resources" : ["*"]
            },
            "diskio" : {
              "measurement" : ["io_time"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval,
              "resources" : ["*"]
            },
            "mem" : {
              "measurement" : ["mem_used_percent"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval
            },
            "netstat" : {
              "measurement" : ["tcp_established", "tcp_time_wait"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval
            },
            "swap" : {
              "measurement" : ["swap_used_percent"],
              "metrics_collection_interval" : var.cloudwatch_agent_config.metrics_collection_interval
            }
          }
        }
      } : {},
      var.cloudwatch_agent_config.enable_logs ? {
        "logs" : {
          "logs_collected" : {
            "files" : {
              "collect_list" : [
                {
                  "file_path" : "/var/log/ecs/ecs-agent.log",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/ecs-agent",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/ecs/ecs-init.log",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/ecs-init",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/ecs/audit.log",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/ecs-audit",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/messages",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/messages",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/secure",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/secure",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/auth.log",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/auth",
                  "timezone" : "UTC"
                },
                {
                  "file_path" : "/var/log/amazon/efs/mount.log",
                  "log_group_name" : var.cluster_name,
                  "log_stream_name" : "{instance_id}/mount.log",
                  "timezone" : "UTC"
                }
              ]
            }
          }
        }
      } : {}
    )
  )
}
