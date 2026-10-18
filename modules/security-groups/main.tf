locals {
  name_prefix = var.name_prefix
  common_tags = var.tags
}

# -----------------------------------------------------------------------------
# ALB Security Group
# Inbound: HTTP 80 from configurable client CIDRs.
# HTTPS 443 only when enable_https_ingress is true (later phase).
# Outbound: only to ECS application targets on the app port.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Security group for Maghad Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  description       = "HTTP from allowed client CIDRs"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_http_cidrs
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  count = var.enable_https_ingress ? 1 : 0

  type              = "ingress"
  description       = "HTTPS from allowed client CIDRs (ACM/listener in later phase)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_http_cidrs
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  description              = "Allow ALB to reach ECS application targets"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.alb.id
}

# -----------------------------------------------------------------------------
# ECS Application Security Group
# No internet inbound. App traffic only from ALB.
# Outbound: PostgreSQL + HTTPS for image pulls, logs, and external APIs.
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name_prefix = "${local.name_prefix}-ecs-"
  description = "Security group for Maghad ECS Fargate tasks"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  description              = "Application traffic from ALB only"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "ecs_egress_postgres" {
  type                     = "egress"
  description              = "Allow ECS tasks to reach PostgreSQL"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.postgres.id
  security_group_id        = aws_security_group.ecs.id
}

# HTTPS egress for ECR image pulls, CloudWatch Logs, SSM (if used), and external APIs.
# Without this (or VPC endpoints), Fargate cannot pull images or ship logs via NAT.
resource "aws_security_group_rule" "ecs_egress_https" {
  type              = "egress"
  description       = "HTTPS for ECR pulls, CloudWatch Logs, and external APIs"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

# DNS resolution (VPC DNS / Route53 resolver)
resource "aws_security_group_rule" "ecs_egress_dns_udp" {
  type              = "egress"
  description       = "DNS UDP for name resolution"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

resource "aws_security_group_rule" "ecs_egress_dns_tcp" {
  type              = "egress"
  description       = "DNS TCP for name resolution"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

# -----------------------------------------------------------------------------
# PostgreSQL Security Group
# TCP 5432 only from ECS SG. No SSH. No internet.
# -----------------------------------------------------------------------------
resource "aws_security_group" "postgres" {
  name_prefix = "${local.name_prefix}-postgres-"
  description = "Security group for Maghad PostgreSQL EC2 instance"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "postgres_ingress_from_ecs" {
  type                     = "ingress"
  description              = "PostgreSQL from ECS tasks only"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  security_group_id        = aws_security_group.postgres.id
}

# HTTPS for SSM agent / package updates via NAT (bootstrap and management)
resource "aws_security_group_rule" "postgres_egress_https" {
  type              = "egress"
  description       = "HTTPS for SSM agent and package updates via NAT"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.postgres.id
}

resource "aws_security_group_rule" "postgres_egress_dns_udp" {
  type              = "egress"
  description       = "DNS UDP for name resolution"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.postgres.id
}

resource "aws_security_group_rule" "postgres_egress_http" {
  type              = "egress"
  description       = "HTTP for package mirrors during bootstrap"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.postgres.id
}
