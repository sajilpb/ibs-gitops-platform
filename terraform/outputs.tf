output "elasticache_redis_endpoints" {
  description = "ElastiCache Redis endpoint details keyed by environment"
  value       = module.elastic-cache.redis_endpoints
}
