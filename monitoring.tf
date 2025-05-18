data "aws_region" "current" {}

data "templatefile" "msk_dashboard" {
  count = local.create_dashboard

  template = file(local.dashboard_template)

  vars = {
    cluster_name = var.cluster_name
    region       = data.aws_region.current.name
  }
}

# Current Dashboard based on DataDog MSK Overview Dashboard
# discussed in an article on their blog:
#   https://www.datadoghq.com/blog/monitor-amazon-msk/

resource "aws_cloudwatch_dashboard" "msk" {
  count = local.create_dashboard

  dashboard_name = var.cluster_name
  dashboard_body = data.templatefile.msk_dashboard[count.index].rendered
}

resource "aws_cloudwatch_metric_alarm" "msk_broker_disk_space" {
  count = local.create_cw_alarm * local.num_of_broker_nodes

  alarm_name                = "${local.cluster_name}-DataLogs-DiskUsed-Broker-${count.index + 1}"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "KafkaDataLogsDiskUsed"
  namespace                 = "AWS/Kafka"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "85"
  alarm_description         = "This metric monitors the MSK Broker Data Logs Disk Usage"
  insufficient_data_actions = []

  dimensions = {
    "Cluster Name" = local.cluster_name
    "Broker ID"    = count.index + 1
  }

  tags = merge(tomap({
    Name = local.cluster_name
  }), var.monitoring_tags, var.tags)
}
