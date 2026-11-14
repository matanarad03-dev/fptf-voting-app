# Map 2c · D3 · Terraform makes up the ledger's lock code (no special chars: they break the connection string).
resource "random_password" "db" {
  length  = 24
  special = false
}

# Map 2c · D3 · The safe (Secrets Manager). recovery 0 = deleted at once on destroy, so you can rebuild the same day.
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name}-db-password"
  recovery_window_in_days = 0
}

# Map 2c · D3 · Puts the lock code inside the safe. In step 4 the workers read it from here (D4).
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# Map 2c · D2 · Note "the ledger stays in the kitchen": the 2 private subnets.
resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

# Map 2c · D2 · The ledger (Postgres 16), locked with the code above, guarded by rds-sg (2b). 💰
# skip_final_snapshot: otherwise destroy fails or leaves a paid snapshot.
resource "aws_db_instance" "main" {
  identifier             = "${local.name}-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "votes"
  username               = "voteadmin"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}
