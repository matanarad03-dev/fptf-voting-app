# ECS cluster, environment variables and secrets of the services, the three calls to the service module

# Map 4.4 · S1 · The staff room: one ECS cluster per building.
resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"
}

# Map 4.4 · S4 / D4 · Shared notes for result and worker: where the ledger is, and which safe holds its code.
locals {
  db_env = {
    DB_HOST = aws_db_instance.main.address
    DB_PORT = tostring(aws_db_instance.main.port)
    DB_USER = aws_db_instance.main.username
    DB_NAME = aws_db_instance.main.db_name
    DB_SSL  = "true"
  }
  db_secrets = { DB_PASSWORD = aws_secretsmanager_secret.db_password.arn }
  redis_host = aws_elasticache_cluster.main.cache_nodes[0].address
}

# Map 4.4 · S2 · Form 1, the waiter: door 80, on the host's vote list, talks to the ticket rail.
module "vote" {
  source = "./modules/service"

  name               = "${local.name}-vote"
  cluster_id         = aws_ecs_cluster.main.id
  image              = "${data.aws_ecr_repository.service["vote"].repository_url}:${var.image_tag}"
  execution_role_arn = aws_iam_role.exec.arn
  subnet_ids         = [for s in aws_subnet.public : s.id]
  security_group_ids = [aws_security_group.ecs.id]
  desired_count      = var.desired_count
  container_port     = 80
  target_group_arn   = aws_lb_target_group.service["vote"].arn

  environment = {
    REDIS_HOST = local.redis_host
    OPTION_A   = var.option_a
    OPTION_B   = var.option_b
  }

  depends_on = [aws_lb_listener.service, aws_iam_role_policy_attachment.exec]
}

# Map 4.4 · S2 · Form 2, the scoreboard: door 8080 (via the host), reads the ledger.
module "result" {
  source = "./modules/service"

  name               = "${local.name}-result"
  cluster_id         = aws_ecs_cluster.main.id
  image              = "${data.aws_ecr_repository.service["result"].repository_url}:${var.image_tag}"
  execution_role_arn = aws_iam_role.exec.arn
  subnet_ids         = [for s in aws_subnet.public : s.id]
  security_group_ids = [aws_security_group.ecs.id]
  desired_count      = var.desired_count
  container_port     = 80
  target_group_arn   = aws_lb_target_group.service["result"].arn

  environment = local.db_env
  secrets     = local.db_secrets

  depends_on = [aws_lb_listener.service, aws_iam_role_policy.read_db_secret]
}

# Map 4.4 · S2 / L3 · Form 3, the cook: no door, no host. Ticket rail → ledger.
module "worker" {
  source = "./modules/service"

  name               = "${local.name}-worker"
  cluster_id         = aws_ecs_cluster.main.id
  image              = "${data.aws_ecr_repository.service["worker"].repository_url}:${var.image_tag}"
  execution_role_arn = aws_iam_role.exec.arn
  subnet_ids         = [for s in aws_subnet.public : s.id]
  security_group_ids = [aws_security_group.ecs.id]
  desired_count      = var.desired_count

  environment = merge({ REDIS_HOST = local.redis_host }, local.db_env)
  secrets     = local.db_secrets

  depends_on = [aws_iam_role_policy.read_db_secret]
}
