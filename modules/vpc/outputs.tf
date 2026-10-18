output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for ALB)"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_id" {
  description = "Private application subnet ID (ECS)"
  value       = aws_subnet.private_app.id
}

output "private_db_subnet_id" {
  description = "Private database subnet ID (PostgreSQL)"
  value       = aws_subnet.private_db.id
}

output "private_app_subnet_cidr" {
  description = "Private application subnet CIDR"
  value       = aws_subnet.private_app.cidr_block
}

output "private_db_subnet_cidr" {
  description = "Private database subnet CIDR"
  value       = aws_subnet.private_db.cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.this.id
}

output "nat_instance_id" {
  description = "NAT instance ID (null if NAT disabled)"
  value       = var.enable_nat ? aws_instance.nat[0].id : null
}

output "nat_public_ip" {
  description = "NAT Elastic IP (null if NAT disabled)"
  value       = var.enable_nat ? aws_eip.nat[0].public_ip : null
}

output "nat_security_group_id" {
  description = "NAT security group ID (null if NAT disabled)"
  value       = var.enable_nat ? aws_security_group.nat[0].id : null
}

output "primary_availability_zone" {
  description = "Primary AZ used for ECS and PostgreSQL"
  value       = local.primary_az
}
