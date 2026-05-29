output "elasticache_redis_endpoints" {
  description = "ElastiCache Redis endpoint details keyed by environment"
  value       = module.elastic-cache.redis_endpoints
}

output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = module.db.eso_irsa_role_arn
}

output "prod_health_check_id" {
  description = "Route53 health check ID for the production endpoint"
  value       = module.cloudwatch.prod_health_check_id
}

output "argo_rollouts_role_arn" {
  description = "IAM Role ARN for Argo Rollouts IRSA (CloudWatch access)"
  value       = module.argocd.argo_rollouts_role_arn
}