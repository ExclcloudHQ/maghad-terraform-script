locals {
  name_prefix = var.name_prefix
  common_tags = var.tags

  primary_az = var.availability_zones[0]
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets (2 AZs for internet-facing ALB)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private Application Subnet (ECS) — single AZ for cost control
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_app_subnet_cidr
  availability_zone       = local.primary_az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-app"
    Tier = "private-app"
  })
}

# -----------------------------------------------------------------------------
# Private Database Subnet (PostgreSQL) — same AZ for cost control
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_db" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_db_subnet_cidr
  availability_zone       = local.primary_az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-db"
    Tier = "private-db"
  })
}

# -----------------------------------------------------------------------------
# Public Route Table
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private Route Tables
# -----------------------------------------------------------------------------
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-app-rt"
  })
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-db-rt"
  })
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "private_db" {
  subnet_id      = aws_subnet.private_db.id
  route_table_id = aws_route_table.private_db.id
}

# Default route via NAT instance when enabled
resource "aws_route" "private_app_nat" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

resource "aws_route" "private_db_nat" {
  count = var.enable_nat ? 1 : 0

  route_table_id         = aws_route_table.private_db.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# -----------------------------------------------------------------------------
# NAT Instance IAM (SSM Session Manager only — no SSH)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "nat_assume" {
  count = var.enable_nat ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nat" {
  count = var.enable_nat ? 1 : 0

  name               = "${local.name_prefix}-nat-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.nat_assume[0].json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "nat_ssm" {
  count = var.enable_nat ? 1 : 0

  role       = aws_iam_role.nat[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat" {
  count = var.enable_nat ? 1 : 0

  name = "${local.name_prefix}-nat-ssm-profile"
  role = aws_iam_role.nat[0].name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-ssm-profile"
  })
}

# -----------------------------------------------------------------------------
# NAT Instance Security Group
# Rules allow private-subnet traffic and required forwarding/SSM egress.
# -----------------------------------------------------------------------------
resource "aws_security_group" "nat" {
  count = var.enable_nat ? 1 : 0

  name_prefix = "${local.name_prefix}-nat-"
  description = "Security group for NAT instance (no SSH; SSM only)"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Allow forwarded traffic from private app and db subnets
resource "aws_security_group_rule" "nat_ingress_private_app" {
  count = var.enable_nat ? 1 : 0

  type              = "ingress"
  description       = "Allow traffic from private app subnet for NAT forwarding"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.private_app_subnet_cidr]
  security_group_id = aws_security_group.nat[0].id
}

resource "aws_security_group_rule" "nat_ingress_private_db" {
  count = var.enable_nat ? 1 : 0

  type              = "ingress"
  description       = "Allow traffic from private db subnet for NAT forwarding"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.private_db_subnet_cidr]
  security_group_id = aws_security_group.nat[0].id
}

# Egress required for NAT forwarding and SSM agent (HTTPS to AWS endpoints)
resource "aws_security_group_rule" "nat_egress_all" {
  count = var.enable_nat ? 1 : 0

  type              = "egress"
  description       = "Allow outbound NAT forwarding and SSM management traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nat[0].id
}

# -----------------------------------------------------------------------------
# NAT Instance (dev cost optimization — single point of failure)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.enable_nat ? 1 : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_instance" "nat" {
  count = var.enable_nat ? 1 : 0

  ami                         = var.nat_ami_id
  instance_type               = var.nat_instance_type
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  iam_instance_profile        = aws_iam_instance_profile.nat[0].name
  source_dest_check           = false

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/nat-bootstrap.log | logger -t nat-bootstrap -s 2>/dev/console) 2>&1

    echo "Configuring NAT instance..."

    # Enable IPv4 forwarding
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/10-nat.conf
    sysctl -p /etc/sysctl.d/10-nat.conf

    # Persist iptables NAT masquerade across reboots (Amazon Linux 2023 / AL2)
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y iptables-services || true
    elif command -v yum >/dev/null 2>&1; then
      yum install -y iptables-services || true
    fi

    PRIMARY_IF=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)
    iptables -t nat -C POSTROUTING -o "$${PRIMARY_IF}" -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o "$${PRIMARY_IF}" -j MASQUERADE

    # Allow forwarding
    iptables -C FORWARD -j ACCEPT 2>/dev/null || iptables -A FORWARD -j ACCEPT

    if command -v service >/dev/null 2>&1; then
      service iptables save 2>/dev/null || true
    fi
    mkdir -p /etc/sysconfig
    iptables-save > /etc/sysconfig/iptables || true

    # Ensure SSM agent is running
    systemctl enable amazon-ssm-agent 2>/dev/null || true
    systemctl start amazon-ssm-agent 2>/dev/null || true

    echo "NAT bootstrap complete on interface $${PRIMARY_IF}"
  EOF
  )

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip_association" "nat" {
  count = var.enable_nat ? 1 : 0

  instance_id   = aws_instance.nat[0].id
  allocation_id = aws_eip.nat[0].id
}
