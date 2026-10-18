output "instance_id" {
  description = "PostgreSQL EC2 instance ID"
  value       = aws_instance.postgres.id
}

output "private_ip" {
  description = "PostgreSQL private IP address"
  value       = aws_instance.postgres.private_ip
}

output "instance_arn" {
  description = "PostgreSQL EC2 instance ARN"
  value       = aws_instance.postgres.arn
}

output "iam_role_name" {
  description = "IAM role name attached via instance profile (SSM)"
  value       = aws_iam_role.postgres.name
}
