# Map 2c · O2 · The ticket rail's address. Step 4: vote and worker connect here.
output "redis_endpoint" {
  value = aws_elasticache_cluster.main.cache_nodes[0].address
}

# Map 2c · O2 · The ledger's address. Step 4: worker and result connect here.
output "db_endpoint" {
  value = aws_db_instance.main.address
}

# Map 4.5 · O2 · The address on the sign: door 80, the voting page.
output "vote_url" {
  value = "http://${aws_lb.main.dns_name}"
}

# Map 4.5 · O2 · Door 8080: the scoreboard.
output "result_url" {
  value = "http://${aws_lb.main.dns_name}:8080"
}
