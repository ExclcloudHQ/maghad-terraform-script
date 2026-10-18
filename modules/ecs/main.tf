locals {
  name_prefix = var.name_prefix
  common_tags = var.tags
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# ECS Cluster (Fargate)
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups (required by awslogs driver in task definitions)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-logs"
  })
}

resource "aws_cloudwatch_log_group" "render_worker" {
  name              = "/ecs/${local.name_prefix}-render-worker"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-render-worker-logs"
  })
}

# -----------------------------------------------------------------------------
# IAM — Task Execution Role (pull images, write logs)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-execution-role"
  })
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid = "ECRAuth"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECRPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${local.name_prefix}-*"
    ]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.api.arn}:*",
      "${aws_cloudwatch_log_group.render_worker.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${local.name_prefix}-ecs-execution-policy"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

# -----------------------------------------------------------------------------
# IAM — Task Role (application runtime; least privilege placeholder)
# -----------------------------------------------------------------------------
# Task role with no AWS API permissions in this phase.
# Attach application-specific policies later (e.g. S3) without granting AdministratorAccess.
resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-task-role"
  })
}

# -----------------------------------------------------------------------------
# API Task Definition & Service
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_image
      essential = true

      portMappings = [
        {
          containerPort = var.api_container_port
          hostPort      = var.api_container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "api"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-task"
  })
}

resource "aws_ecs_service" "api" {
  name            = "${local.name_prefix}-api"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = var.api_container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Avoid cycle: ALB target group must exist first; service depends on TG ARN input.
  depends_on = [aws_iam_role_policy.execution]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-api-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# -----------------------------------------------------------------------------
# Render Worker Task Definition & Service
# Assumption: render worker does NOT require an ALB listener or target group.
# It runs in the private app subnet with no public IP and uses its own port
# for any container-internal listeners. Inbound is not opened on the ECS SG
# for this port; add rules later if worker-to-worker or sidecar health checks
# are required.
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "render_worker" {
  family                   = "${local.name_prefix}-render-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.render_worker_cpu
  memory                   = var.render_worker_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "render-worker"
      image     = var.render_worker_image
      essential = true

      portMappings = [
        {
          containerPort = var.render_worker_container_port
          hostPort      = var.render_worker_container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.render_worker.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "render-worker"
        }
      }
    }
  ])

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-render-worker-task"
  })
}

resource "aws_ecs_service" "render_worker" {
  name            = "${local.name_prefix}-render-worker"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.render_worker.arn
  desired_count   = var.render_worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  depends_on = [aws_iam_role_policy.execution]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-render-worker-service"
  })

  lifecycle {
    ignore_changes = [desired_count]
  }
}
