output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ECS application security group ID"
  value       = aws_security_group.ecs.id
}

output "postgres_security_group_id" {
  description = "PostgreSQL security group ID"
  value       = aws_security_group.postgres.id
}
