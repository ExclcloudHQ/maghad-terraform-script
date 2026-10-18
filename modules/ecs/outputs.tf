output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "api_service_name" {
  description = "API ECS service name"
  value       = aws_ecs_service.api.name
}

output "render_worker_service_name" {
  description = "Render worker ECS service name"
  value       = aws_ecs_service.render_worker.name
}

output "api_task_definition_arn" {
  description = "API task definition ARN"
  value       = aws_ecs_task_definition.api.arn
}

output "render_worker_task_definition_arn" {
  description = "Render worker task definition ARN"
  value       = aws_ecs_task_definition.render_worker.arn
}

output "execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.task.arn
}

output "api_log_group_name" {
  description = "CloudWatch log group for API"
  value       = aws_cloudwatch_log_group.api.name
}

output "render_worker_log_group_name" {
  description = "CloudWatch log group for render worker"
  value       = aws_cloudwatch_log_group.render_worker.name
}
