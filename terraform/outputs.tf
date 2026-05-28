output "elasticache_redis_endpoints" {
  description = "ElastiCache Redis endpoint details keyed by environment"
  value       = module.elastic-cache.redis_endpoints
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator via IRSA"
  value       = module.external_secrets.external_secrets_role_arn
}
