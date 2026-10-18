output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_id" {
  description = "Private application subnet ID"
  value       = module.vpc.private_app_subnet_id
}

output "private_db_subnet_id" {
  description = "Private database subnet ID"
  value       = module.vpc.private_db_subnet_id
}

output "nat_instance_id" {
  description = "NAT instance ID"
  value       = module.vpc.nat_instance_id
}

output "nat_public_ip" {
  description = "NAT Elastic IP"
  value       = module.vpc.nat_public_ip
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = module.alb.api_target_group_arn
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "api_service_name" {
  description = "API ECS service name"
  value       = module.ecs.api_service_name
}

output "render_worker_service_name" {
  description = "Render worker ECS service name"
  value       = module.ecs.render_worker_service_name
}

output "postgres_instance_id" {
  description = "PostgreSQL EC2 instance ID"
  value       = module.postgres.instance_id
}

output "postgres_private_ip" {
  description = "PostgreSQL private IP"
  value       = module.postgres.private_ip
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ECS security group ID"
  value       = module.security_groups.ecs_security_group_id
}

output "postgres_security_group_id" {
  description = "PostgreSQL security group ID"
  value       = module.security_groups.postgres_security_group_id
}
