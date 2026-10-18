variable "name_prefix" {
  description = "Name prefix for resources (e.g. maghad-dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (must be length 2 for ALB)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required for the ALB."
  }
}

variable "private_app_subnet_cidr" {
  description = "CIDR block for the private application subnet (ECS tasks)"
  type        = string
}

variable "private_db_subnet_cidr" {
  description = "CIDR block for the private database subnet (PostgreSQL)"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for public subnets (index 0 is used for ECS/PostgreSQL cost control)"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required."
  }
}

variable "enable_nat" {
  description = "Whether to create a NAT instance for private subnet internet egress. If false, private egress will not work without VPC endpoints."
  type        = bool
  default     = true
}

variable "nat_ami_id" {
  description = "AMI ID for the NAT instance (supported Amazon Linux recommended). Required when enable_nat is true."
  type        = string
  default     = ""
}

variable "nat_instance_type" {
  description = "Instance type for the NAT instance"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
