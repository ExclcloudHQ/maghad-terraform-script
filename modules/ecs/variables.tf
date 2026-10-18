variable "name_prefix" {
  description = "Name prefix for resources (e.g. maghad-dev)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Fargate tasks (no public IP)"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "api_target_group_arn" {
  description = "ALB target group ARN for the API service"
  type        = string
}

variable "api_image" {
  description = "ECR image URI for the API container (must exist before successful service deployment)"
  type        = string
}

variable "render_worker_image" {
  description = "ECR image URI for the render worker container (must exist before successful service deployment)"
  type        = string
}

variable "api_cpu" {
  description = "CPU units for the API task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "api_memory" {
  description = "Memory (MiB) for the API task"
  type        = number
  default     = 2048
}

variable "api_container_port" {
  description = "Container port for the API service"
  type        = number
  default     = 8080
}

variable "api_desired_count" {
  description = "Desired number of API tasks"
  type        = number
  default     = 1
}

variable "render_worker_cpu" {
  description = "CPU units for the render worker task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "render_worker_memory" {
  description = "Memory (MiB) for the render worker task"
  type        = number
  default     = 2048
}

variable "render_worker_container_port" {
  description = "Container port for the render worker (no ALB; documented for network clarity)"
  type        = number
  default     = 8081
}

variable "render_worker_desired_count" {
  description = "Desired number of render worker tasks"
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the task execution role may pull from"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
