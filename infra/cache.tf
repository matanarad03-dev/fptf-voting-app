# Map 2c · D1 · Note "the ticket rail stays in the kitchen": the 2 private subnets.
resource "aws_elasticache_subnet_group" "main" {
  name       = "${local.name}-redis"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

# Map 2c · D1 · The ticket rail (Redis 7.1): vote hangs votes, worker takes them. 💰
# Guarded by redis-sg (2b). Its address goes out as output redis_endpoint.
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${local.name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
}
