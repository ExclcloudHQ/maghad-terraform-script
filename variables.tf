########################################
# Core
########################################

variable "aws_region" {
  description = "AWS region for Maghad infrastructure"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "Maghad"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "default_tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "Maghad"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

########################################
# Networking
########################################

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (two AZs for ALB)"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_app_subnet_cidr" {
  description = "Private application subnet CIDR (ECS)"
  type        = string
  default     = "10.20.11.0/24"
}

variable "private_db_subnet_cidr" {
  description = "Private database subnet CIDR (PostgreSQL)"
  type        = string
  default     = "10.20.21.0/24"
}

variable "availability_zones" {
  description = "Availability zones (index 0 used for ECS and PostgreSQL)"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "enable_nat" {
  description = "Create NAT instance for private subnet egress. If false, private internet egress will not work without VPC endpoints."
  type        = bool
  default     = true
}

variable "nat_ami_id" {
  description = "AMI ID for NAT instance (Amazon Linux 2023 recommended). Required when enable_nat is true."
  type        = string
  default     = ""
}

variable "nat_instance_type" {
  description = "NAT instance type"
  type        = string
  default     = "t3.micro"
}

########################################
# Security
########################################

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach ALB HTTP :80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "API container / ALB target port"
  type        = number
  default     = 8080
}

########################################
# ECR
########################################

variable "ecr_repository_names" {
  description = "Short names for ECR repositories"
  type        = list(string)
  default     = ["api", "render-worker"]
}

variable "ecr_tagged_image_count" {
  description = "Number of tagged images to retain"
  type        = number
  default     = 10
}

variable "ecr_untagged_image_days" {
  description = "Expire untagged images after this many days"
  type        = number
  default     = 7
}

########################################
# ECS
########################################

variable "api_image" {
  description = "Placeholder/configurable ECR image URI for API (must exist for successful deployment)"
  type        = string
}

variable "render_worker_image" {
  description = "Placeholder/configurable ECR image URI for render worker"
  type        = string
}

variable "api_cpu" {
  description = "API task CPU units"
  type        = number
  default     = 1024
}

variable "api_memory" {
  description = "API task memory MiB"
  type        = number
  default     = 2048
}

variable "api_desired_count" {
  description = "API service desired count"
  type        = number
  default     = 1
}

variable "render_worker_cpu" {
  description = "Render worker task CPU units"
  type        = number
  default     = 1024
}

variable "render_worker_memory" {
  description = "Render worker task memory MiB"
  type        = number
  default     = 2048
}

variable "render_worker_container_port" {
  description = "Render worker container port (no ALB)"
  type        = number
  default     = 8081
}

variable "render_worker_desired_count" {
  description = "Render worker desired count"
  type        = number
  default     = 1
}

########################################
# ALB
########################################

variable "health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health"
}

variable "health_check_matcher" {
  description = "ALB health check success codes"
  type        = string
  default     = "200"
}

########################################
# PostgreSQL EC2
########################################

variable "postgres_ami_id" {
  description = "AMI ID for PostgreSQL EC2 (Amazon Linux 2023 recommended)"
  type        = string
}

variable "postgres_instance_type" {
  description = "PostgreSQL EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "postgres_major_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_volume_size_gb" {
  description = "PostgreSQL root volume size GiB"
  type        = number
  default     = 50
}

variable "postgres_database_name" {
  description = "Initial database name"
  type        = string
  default     = "maghad"
}
