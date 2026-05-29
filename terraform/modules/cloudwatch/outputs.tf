output "prod_health_check_id" {
  description = "Route53 health check ID for the production endpoint"
  value       = aws_route53_health_check.prod.id
}

output "prod_health_alarm_arn" {
  description = "CloudWatch alarm ARN for production endpoint health"
  value       = aws_cloudwatch_metric_alarm.prod_health.arn
}
