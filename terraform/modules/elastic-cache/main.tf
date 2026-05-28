resource "aws_elasticache_serverless_cache" "example" {
  engine = "redis"
  name   = "rediscache-nodeapp"
  cache_usage_limits {
    data_storage {
      maximum = 1
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 1000
    }
  }
  daily_snapshot_time      = "09:00"
  description              = "Test Server"
  major_engine_version     = "7"
  snapshot_retention_limit = 1
  security_group_ids       = var.Vpc_id
  subnet_ids               = var.subnet_ids
}