output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID."
}

output "vpc_ipv4_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "VPC IPv4 CIDR."
}

output "vpc_ipv6_cidr" {
  value       = aws_vpc_ipv6_cidr_block_association.this.ipv6_cidr_block
  description = "VPC IPv6 /56 CIDR."
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "Public subnet IDs (16)."
}

output "public_subnet_ipv4_cidrs" {
  value       = [for s in aws_subnet.public : s.cidr_block]
  description = "Public IPv4 CIDRs (16)."
}

output "public_subnet_ipv6_cidrs" {
  value       = [for s in aws_subnet.public : s.ipv6_cidr_block]
  description = "Public IPv6 /64 CIDRs (16)."
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "Private subnet IDs (16)."
}

output "private_subnet_ipv4_cidrs" {
  value       = [for s in aws_subnet.private : s.cidr_block]
  description = "Private IPv4 CIDRs (16)."
}

output "private_subnet_ipv6_cidrs" {
  value       = [for s in aws_subnet.private : s.ipv6_cidr_block]
  description = "Private IPv6 /64 CIDRs (16)."
}

output "route_table_public_id" {
  value       = aws_route_table.public.id
  description = "Public route table ID."
}

output "route_table_private_id" {
  value       = aws_route_table.private.id
  description = "Private route table ID."
}

output "nat_gateway_id" {
  value       = try(aws_nat_gateway.nat[0].id, null)
  description = "NAT Gateway ID (null if nat_mode != single)."
}

output "internet_gateway_id" {
  value       = try(aws_internet_gateway.igw[0].id, null)
  description = "Internet Gateway ID."
}

output "egress_only_igw_id" {
  value       = try(aws_egress_only_internet_gateway.eoigw[0].id, null)
  description = "Egress-only Internet Gateway ID."
}
