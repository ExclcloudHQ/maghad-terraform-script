terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
  }

  # Remote backend is intentionally NOT configured in this phase.
  # After creating the state bucket and prerequisites manually, add a
  # backend "s3" block in envs/dev (or a separate backend.hcl) and run:
  #   terraform init -migrate-state
}
