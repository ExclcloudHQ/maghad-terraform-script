variable "name_prefix" {
  description = "Name prefix for repositories (e.g. maghad-dev)"
  type        = string
}

variable "repository_names" {
  description = "Short repository names appended to name_prefix (e.g. api, render-worker)"
  type        = list(string)

  validation {
    condition     = length(var.repository_names) > 0
    error_message = "At least one ECR repository name is required."
  }
}

variable "tagged_image_count" {
  description = "Number of recent tagged images to retain per repository"
  type        = number
  default     = 10

  validation {
    condition     = var.tagged_image_count >= 1
    error_message = "tagged_image_count must be at least 1."
  }
}

variable "untagged_image_days" {
  description = "Expire untagged images older than this many days"
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_days >= 1
    error_message = "untagged_image_days must be at least 1."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
