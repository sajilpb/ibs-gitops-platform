resource "aws_security_group" "redis_sg" {
  for_each = var.redis_environments

  name        = "${each.value.name}-sg"
  description = "Security group for Redis ElastiCache"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Redis traffic from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }
}

resource "aws_elasticache_serverless_cache" "example" {
  for_each = var.redis_environments

  engine = "redis"
  name   = each.value.name

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
  security_group_ids       = [aws_security_group.redis_sg[each.key].id]
  subnet_ids               = var.subnet_ids
}
