resource "aws_vpc" "private_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "${var.name}-vpc" }
}

resource "aws_subnet" "private" {
  for_each = toset(var.azs)
  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = var.private_subnet_cidrs[index(var.azs, each.key)]
  availability_zone       = each.key
  map_public_ip_on_launch = false # Keeping private
  tags = { Name = "${var.name}-private-${each.key}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.private_vpc.id
  tags   = { Name = "${var.name}-rtb-private" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Gateway endpoint for S3 so tasks can access buckets privately
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.private_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [aws_route_table.private.id]
  tags = { Name = "${var.name}-vpce-s3" }
}

# Security group for interface endpoints (and for tasks)
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints-sg"
  description = "Allow VPC endpoints traffic inside VPC"
  vpc_id      = aws_vpc.private_vpc.id

  # Allow VPC internal
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.private_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.private_vpc.cidr_block]
  }
  tags = { Name = "${var.name}-endpoints-sg" }
}

# Interface endpoints required for private Fargate pulls/telemetry/logs
locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "ecs",
    "ecs-telemetry"
  ]
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each            = toset(local.interface_services)
  vpc_id              = aws_vpc.private_vpc.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  tags                = { Name = "${var.name}-vpce-${each.key}" }
}
