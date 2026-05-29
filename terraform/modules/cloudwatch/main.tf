##############################################
# Route53 Health Check — production endpoint
##############################################

resource "aws_route53_health_check" "prod" {
  fqdn              = var.prod_domain
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "${var.env_name}-prod-health-check"
  }
}

##############################################
# CloudWatch Alarms — endpoint availability
##############################################

resource "aws_cloudwatch_metric_alarm" "prod_health" {
  alarm_name          = "${var.env_name}-prod-endpoint-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Production endpoint ${var.prod_domain} is unhealthy"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.prod.id
  }
}

