# Reads (does not create) the list of AZs that are up in this region.
# Used by: local.azs below.
data "aws_availability_zones" "available" {
  state = "available"
}

# The first 2 AZs = the two wings of the building.
# Used by: both subnet blocks (for_each).
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}


# VPC = the restaurant building. Our private network (10.10.0.0/16 in dev).
# Everything below lives inside it (vpc_id = aws_vpc.main.id).
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # lets resources resolve names (e.g. the RDS endpoint)
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}-vpc"
  }
}

# Internet gateway = the front entrance from the street.
# Attached to: the VPC. Used by: the public route table (0.0.0.0/0 -> here).
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-igw"
  }
}

# Public subnets = the dining hall, one per AZ (10.10.0.0/24, 10.10.1.0/24).
# Inside: the VPC. Linked to: the public route table (so they reach the internet).
# Later: the ALB and the ECS tasks run here.
resource "aws_subnet" "public" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

# Private subnets = the kitchen / storeroom, one per AZ (10.10.10.0/24, 10.10.11.0/24).
# Inside: the VPC. Linked to: the private route table (no internet route).
# Later: Redis and Postgres live here.
resource "aws_subnet" "private" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

# Public route table = the sign "to the street, use the front entrance".
# Route: everything not local (0.0.0.0/0) -> the internet gateway.
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

# Private route table = a sign with no exit. Only the built-in local route
# (traffic inside the VPC). Nothing here can reach the internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-private-rt"
  }
}

# Hangs the public sign in each public subnet (2 links).
# Connects: aws_subnet.public[*] <-> aws_route_table.public.
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Hangs the private sign in each private subnet (2 links).
# Connects: aws_subnet.private[*] <-> aws_route_table.private.
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}


# Security groups = bouncers. Each one is attached later to a resource.

# ALB bouncer: lets anyone in on 80 (vote) and 8080 (result).
# Attached later to: the load balancer. Referenced by: the ecs SG.
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
    protocol    = "-1" # all traffic out
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

# ECS bouncer: port 80 only from whoever carries the alb SG (the host).
# Attached later to: the vote/result/worker tasks. Referenced by: redis and rds SGs.
# Egress all: tasks pull images, write logs, read the secret.
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

# Redis bouncer: port 6379 only from the ECS tasks.
# Attached later to: the ElastiCache cluster (cache.tf).
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

# Postgres bouncer: port 5432 only from the ECS tasks.
# Attached later to: the RDS instance (database.tf).
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
