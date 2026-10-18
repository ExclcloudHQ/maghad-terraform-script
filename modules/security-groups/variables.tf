variable "name_prefix" {
  description = "Name prefix for resources (e.g. maghad-dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on HTTP port 80"
  type        = list(string)

  validation {
    condition     = length(var.allowed_http_cidrs) > 0
    error_message = "At least one allowed HTTP client CIDR is required."
  }
}

variable "app_port" {
  description = "Application container port that the ALB forwards to (ECS API)"
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port > 0 && var.app_port < 65536
    error_message = "app_port must be a valid TCP port."
  }
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "enable_https_ingress" {
  description = "Whether to allow HTTPS 443 on the ALB SG (listener added in a later phase)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
