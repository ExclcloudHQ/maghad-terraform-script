locals {
  name_prefix = var.name_prefix
  common_tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM — SSM Session Manager (no SSH)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "postgres" {
  name               = "${local.name_prefix}-postgres-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres-ssm-role"
  })
}

resource "aws_iam_role_policy_attachment" "postgres_ssm" {
  role       = aws_iam_role.postgres.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "postgres" {
  name = "${local.name_prefix}-postgres-ssm-profile"
  role = aws_iam_role.postgres.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres-ssm-profile"
  })
}

# -----------------------------------------------------------------------------
# PostgreSQL EC2 Instance (private subnet, no public IP, no SSH)
#
# Credentials are NOT set by Terraform. After apply, an operator must
# initialize the database password via SSM Session Manager (see README).
# -----------------------------------------------------------------------------
resource "aws_instance" "postgres" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.postgres.name

  associate_public_ip_address = false

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    postgres_major_version = var.postgres_major_version
    database_name          = var.database_name
    vpc_cidr               = var.vpc_cidr
  }))

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
