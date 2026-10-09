# modules/vpc/outputs.tf

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The primary IPv4 CIDR block of the VPC."
  value       = var.vpc_cidr
}

output "availability_zones" {
  description = "A list of Availability Zones specified for the VPC."
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "A map of public subnet IDs, keyed by AZ index."
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "A map of private subnet IDs, keyed by AZ index."
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "gwlb_subnet_ids" {
  description = "A map of GWLB subnet IDs, keyed by AZ index."
  value       = { for k, v in aws_subnet.gwlb : k => v.id }
}

output "cc_subnet_ids" {
  description = "A map of conditionally created CC subnet IDs, keyed by AZ index."
  value       = { for k, v in aws_subnet.cc : k => v.id }
}

output "public_route_table_id" {
  description = "The ID of the single public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "A map of private route table IDs, keyed by AZ index."
  value       = { for k, v in aws_route_table.private : k => v.id }
}

output "gwlb_route_table_ids" {
  description = "A map of GWLB route table IDs, keyed by AZ index."
  value       = { for k, v in aws_route_table.gwlb : k => v.id }
}

output "cc_route_table_ids" {
  description = "A map of conditionally created CC route table IDs, keyed by AZ index."
  value       = { for k, v in aws_route_table.cc : k => v.id }
}

output "public_nat_gateway_public_ips" {
  description = "List of public EIPs for the NAT Gateways."
  value       = [for gw in aws_nat_gateway.this : gw.public_ip]
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

# --- SUBNET OUTPUTS ---


output "public_subnet_cidrs" {
  description = "List of CIDR blocks of public subnets."
  value       = values(aws_subnet.public)[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks of private subnets."
  value       = values(aws_subnet.private)[*].cidr_block
}


output "gwlb_subnet_cidrs" {
  description = "List of CIDR blocks of GWLB subnets."
  value       = values(aws_subnet.gwlb)[*].cidr_block
}

output "cc_subnet_cidrs" {
  description = "List of CIDR blocks of Cloud Connector subnets."
  value       = values(aws_subnet.cc)[*].cidr_block
}