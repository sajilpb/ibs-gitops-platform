output "redis_endpoints" {
  description = "ElastiCache Redis endpoint details keyed by environment"
  value = {
    for env, cache in aws_elasticache_serverless_cache.example : env => {
      host = cache.endpoint[0].address
      port = cache.endpoint[0].port
    }
  }
}
