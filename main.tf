# -----------------------------------------------------------------------------
# Maghad infrastructure stack (reusable module composition)
#
# Prefer envs/dev as the working directory entry point. That environment
# either calls this root as a module or wires the child modules directly.
# -----------------------------------------------------------------------------

locals {
  # Naming convention: maghad-dev-resource-name
  name_prefix_normalized = "maghad-${var.environment}"

  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.default_tags
  )
}

check "nat_ami_required" {
  assert {
    condition     = !var.enable_nat || length(var.nat_ami_id) > 0
    error_message = "nat_ami_id must be set when enable_nat is true."
  }
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix             = local.name_prefix_normalized
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_app_subnet_cidr = var.private_app_subnet_cidr
  private_db_subnet_cidr  = var.private_db_subnet_cidr
  availability_zones      = var.availability_zones
  enable_nat              = var.enable_nat
  nat_ami_id              = var.nat_ami_id
  nat_instance_type       = var.nat_instance_type
  tags                    = local.tags
}

module "security_groups" {
  source = "./modules/security-groups"

  name_prefix        = local.name_prefix_normalized
  vpc_id             = module.vpc.vpc_id
  allowed_http_cidrs = var.allowed_http_cidrs
  app_port           = var.app_port
  tags               = local.tags
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix         = local.name_prefix_normalized
  repository_names    = var.ecr_repository_names
  tagged_image_count  = var.ecr_tagged_image_count
  untagged_image_days = var.ecr_untagged_image_days
  tags                = local.tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix          = local.name_prefix_normalized
  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  security_group_id    = module.security_groups.alb_security_group_id
  target_port          = var.app_port
  health_check_path    = var.health_check_path
  health_check_matcher = var.health_check_matcher
  tags                 = local.tags
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix                  = local.name_prefix_normalized
  private_subnet_ids           = [module.vpc.private_app_subnet_id]
  ecs_security_group_id        = module.security_groups.ecs_security_group_id
  api_target_group_arn         = module.alb.api_target_group_arn
  api_image                    = var.api_image
  render_worker_image          = var.render_worker_image
  api_cpu                      = var.api_cpu
  api_memory                   = var.api_memory
  api_container_port           = var.app_port
  api_desired_count            = var.api_desired_count
  render_worker_cpu            = var.render_worker_cpu
  render_worker_memory         = var.render_worker_memory
  render_worker_container_port = var.render_worker_container_port
  render_worker_desired_count  = var.render_worker_desired_count
  ecr_repository_arns          = values(module.ecr.repository_arns)
  tags                         = local.tags

  depends_on = [module.alb]
}

module "postgres" {
  source = "./modules/postgres-ec2"

  name_prefix            = local.name_prefix_normalized
  subnet_id              = module.vpc.private_db_subnet_id
  security_group_id      = module.security_groups.postgres_security_group_id
  ami_id                 = var.postgres_ami_id
  instance_type          = var.postgres_instance_type
  postgres_major_version = var.postgres_major_version
  volume_size_gb         = var.postgres_volume_size_gb
  database_name          = var.postgres_database_name
  vpc_cidr               = var.vpc_cidr
  tags                   = local.tags
}
