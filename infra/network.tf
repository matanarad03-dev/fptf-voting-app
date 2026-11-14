# Map 2a · The two wings: reads (does not create) the AZs that are up in the region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Map 2a · Picks the first 2 AZs = the two wings. Used by both subnet blocks.
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}


# Map 2a · N1 · The restaurant building (10.10.0.0/16 in dev).
# Everything below lives inside it (vpc_id = aws_vpc.main.id).
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Map 2a · N3 · The front entrance from the street.
# Attached to the VPC; the public route table sends 0.0.0.0/0 here.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-igw"
  }
}

# Map 2a · N2 · The dining hall, one per wing (10.10.0.0/24, 10.10.1.0/24).
# Public via the public route table. Step 4: the ALB and the ECS tasks sit here.
resource "aws_subnet" "public" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

# Map 2a · N2 · The kitchen, one per wing (10.10.10.0/24, 10.10.11.0/24).
# No internet route. Step 2c: Redis and Postgres sit here.
resource "aws_subnet" "private" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

# Map 2a · N3 · Sign "to the street: use the front entrance".
# Everything not local (0.0.0.0/0) goes to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name}-public-rt"
  }
}

# Map 2a · N3 · A sign with no exit: only traffic inside the VPC (no NAT).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-private-rt"
  }
}

# Map 2a · N3 · Hangs the public sign in each dining hall (2 links).
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Map 2a · N3 · Hangs the private sign in each kitchen (2 links).
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


# Map 2b · N5 · The host's bouncer: anyone from the street on 80 (vote) and 8080 (result).
# Attached to the ALB in step 4.
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Load balancer: HTTP from the internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "vote"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "result"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

# Map 2b · N5 · The workers' bouncer: port 80 only from the host (alb-sg). Out: everything
# (pull images, write logs, read the secret). Attached to the 3 services in step 4.
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "ECS tasks: HTTP only from the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "from the ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-ecs-sg"
  }
}

# Map 2b · N5 · The ticket rail's bouncer: 6379 only from the workers. Used in cache.tf (2c).
resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Redis: only from the ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${local.name}-redis-sg"
  }
}

# Map 2b · N5 · The ledger's bouncer: 5432 only from the workers. Used in database.tf (2c).
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Postgres: only from the ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = {
    Name = "${local.name}-rds-sg"
  }
}
