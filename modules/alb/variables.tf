variable "name_prefix" {
  description = "Name prefix for resources (e.g. maghad-dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB (two AZs)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "ALB requires at least two public subnets in different AZs."
  }
}

variable "security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "target_port" {
  description = "Port the target group forwards to (ECS API container port)"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the API target group"
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "HTTP success codes for health checks (e.g. 200 or 200-399)"
  type        = string
  default     = "200"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
