variable "name_prefix" {
  description = "Name prefix for resources (e.g. maghad-dev)"
  type        = string
}

variable "subnet_id" {
  description = "Private database subnet ID"
  type        = string
}

variable "security_group_id" {
  description = "PostgreSQL security group ID"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the PostgreSQL host (Amazon Linux 2023 recommended)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for PostgreSQL"
  type        = string
  default     = "t3.medium"
}

variable "postgres_major_version" {
  description = "PostgreSQL major version to install (explicitly supported, e.g. 16)"
  type        = string
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16", "17"], var.postgres_major_version)
    error_message = "postgres_major_version must be one of: 14, 15, 16, 17."
  }
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GiB (gp3, encrypted)"
  type        = number
  default     = 50

  validation {
    condition     = var.volume_size_gb >= 20
    error_message = "volume_size_gb must be at least 20."
  }
}

variable "database_name" {
  description = "Initial database name to create (no credentials stored in Terraform)"
  type        = string
  default     = "maghad"
}

variable "vpc_cidr" {
  description = "VPC CIDR used in pg_hba.conf for host scram entries (SG still enforces ECS-only access)"
  type        = string
  default     = "10.20.0.0/16"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
