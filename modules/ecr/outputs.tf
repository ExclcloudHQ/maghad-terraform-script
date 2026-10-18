output "repository_urls" {
  description = "Map of repository short name to repository URL"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository short name to repository ARN"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.arn
  }
}

output "repository_names" {
  description = "Map of repository short name to full repository name"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.name
  }
}
