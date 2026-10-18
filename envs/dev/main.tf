# =============================================================================
# Maghad Development Environment — entry point
# Working directory: envs/dev
# =============================================================================

module "maghad" {
  source = "../.."

  aws_region   = var.aws_region
  project      = var.project
  environment  = var.environment
  default_tags = var.default_tags

  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_app_subnet_cidr = var.private_app_subnet_cidr
  private_db_subnet_cidr  = var.private_db_subnet_cidr
  availability_zones      = var.availability_zones

  enable_nat        = var.enable_nat
  nat_ami_id        = var.nat_ami_id
  nat_instance_type = var.nat_instance_type

  allowed_http_cidrs = var.allowed_http_cidrs
  app_port           = var.app_port

  ecr_repository_names    = var.ecr_repository_names
  ecr_tagged_image_count  = var.ecr_tagged_image_count
  ecr_untagged_image_days = var.ecr_untagged_image_days

  api_image           = var.api_image
  render_worker_image = var.render_worker_image

  api_cpu           = var.api_cpu
  api_memory        = var.api_memory
  api_desired_count = var.api_desired_count

  render_worker_cpu            = var.render_worker_cpu
  render_worker_memory         = var.render_worker_memory
  render_worker_container_port = var.render_worker_container_port
  render_worker_desired_count  = var.render_worker_desired_count

  health_check_path    = var.health_check_path
  health_check_matcher = var.health_check_matcher

  postgres_ami_id         = var.postgres_ami_id
  postgres_instance_type  = var.postgres_instance_type
  postgres_major_version  = var.postgres_major_version
  postgres_volume_size_gb = var.postgres_volume_size_gb
  postgres_database_name  = var.postgres_database_name
}
