output "elasticache_redis_endpoints" {
  description = "ElastiCache Redis endpoint details keyed by environment"
  value       = module.elastic-cache.redis_endpoints
}

output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  value       = module.db.eso_irsa_role_arn
}