terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

data "aws_availability_zones" "this" {
  state = "available"
}

locals {
  # 32 subnets => add +5 bits to the VPC IPv4 prefix
  ipv4_newbits = 5

  azs = data.aws_availability_zones.this.names

  # Indices: 0..31 (32 total); first 16 = public, last 16 = private
  indices_public = tolist([for i in range(32) : i if i < 16])
  indices_private = tolist([for i in range(32) : i if i >= 16])

  # Distribute subnets round-robin across AZs by index
  az_for_index = [for i in range(32) : local.azs[i % length(local.azs)]]

  common_tags = merge(
    {
      "Project" = var.project_name
      "Module"  = "vpc32-dualstack"
    },
    var.tags
  )
}

# ------------------------
# VPC (IPv4 + IPv6)
# ------------------------
resource "aws_vpc" "this" {
  cidr_block                           = var.vpc_cidr
  enable_dns_support                   = true
  enable_dns_hostnames                 = true
  assign_generated_ipv6_cidr_block     = false # we attach explicitly below

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Attach an Amazon-provided IPv6 /56 to the VPC
resource "aws_vpc_ipv6_cidr_block_association" "this" {
  vpc_id = aws_vpc.this.id

  # Optional: pin to the region's network border group (normally region default)
  # ipv6_cidr_block_network_border_group = var.ipv6_network_border_group
}

# ------------------------
# Internet Gateways
# ------------------------
resource "aws_internet_gateway" "igw" {
  count = var.enable_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

# Egress-only IGW for IPv6 from private subnets
resource "aws_egress_only_internet_gateway" "eoigw" {
  count = var.enable_egress_only_igw ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, { Name = "${var.project_name}-eoigw" })
}

# ------------------------
# Derive IPv4/IPv6 subnet CIDRs
# ------------------------
locals {
  # IPv4 subnet CIDRs (32 total)
  subnet_ipv4_cidrs = [for i in range(32) : cidrsubnet(var.vpc_cidr, local.ipv4_newbits, i)]

  # IPv6 subnet CIDRs (32 x /64) derived from VPC /56
  # /56 + 8 newbits => /64
  subnet_ipv6_cidrs = [for i in range(32) : cidrsubnet(aws_vpc_ipv6_cidr_block_association.this.ipv6_cidr_block, 8, i)]

  # Slice by type
  pub_ipv4 = [for i in local.indices_public  : local.subnet_ipv4_cidrs[i]]
  prv_ipv4 = [for i in local.indices_private : local.subnet_ipv4_cidrs[i]]

  pub_ipv6 = [for i in local.indices_public  : local.subnet_ipv6_cidrs[i]]
  prv_ipv6 = [for i in local.indices_private : local.subnet_ipv6_cidrs[i]]

  pub_azs  = [for i in local.indices_public  : local.az_for_index[i]]
  prv_azs  = [for i in local.indices_private : local.az_for_index[i]]
}

# ------------------------
# Subnets (16 public + 16 private), dual-stack
# ------------------------
resource "aws_subnet" "public" {
  count = 16
  vpc_id                          = aws_vpc.this.id
  availability_zone               = local.pub_azs[count.index]
  cidr_block                      = local.pub_ipv4[count.index]
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = local.pub_ipv6[count.index]
  map_public_ip_on_launch         = true

  tags = merge(local.common_tags, {
    Name = format("%s-pub-%02d-%s",
      var.project_name,
      count.index + 1,
      replace(local.pub_azs[count.index], "/[a-z-]/", "")
    ),
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = 16
  vpc_id                          = aws_vpc.this.id
  availability_zone               = local.prv_azs[count.index]
  cidr_block                      = local.prv_ipv4[count.index]
  assign_ipv6_address_on_creation = true
  ipv6_cidr_block                 = local.prv_ipv6[count.index]
  map_public_ip_on_launch         = false

  tags = merge(local.common_tags, {
    Name = format("%s-prv-%02d-%s",
      var.project_name,
      count.index + 1,
      replace(local.prv_azs[count.index], "/[a-z-]/", "")
    ),
    Tier = "private"
  })
}

# ------------------------
# NAT (single) for private IPv4 egress
# ------------------------
# Place NAT in the first public subnet
resource "aws_eip" "nat" {
  count = var.nat_mode == "single" ? 1 : 0
  domain = "vpc"
  tags = merge(local.common_tags, { Name = "${var.project_name}-nat-eip" })
}

resource "aws_nat_gateway" "nat" {
  count         = var.nat_mode == "single" ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.common_tags, { Name = "${var.project_name}-nat" })

  depends_on = [aws_internet_gateway.igw]
}

# ------------------------
# Route tables
# ------------------------

# Public RT: IPv4 0.0.0.0/0 and IPv6 ::/0 to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, { Name = "${var.project_name}-rt-public" })
}

resource "aws_route" "public_ipv4_default" {
  count                  = var.enable_internet_gateway ? 1 : 0
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw[0].id
}

resource "aws_route" "public_ipv6_default" {
  count                      = var.enable_internet_gateway ? 1 : 0
  route_table_id             = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                 = aws_internet_gateway.igw[0].id
}

# Associate all public subnets to public RT
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private RT: IPv4 default -> NAT (single); IPv6 default -> EOIGW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, { Name = "${var.project_name}-rt-private" })
}

resource "aws_route" "private_ipv4_default" {
  count                  = var.nat_mode == "single" ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route" "private_ipv6_default" {
  count                      = var.enable_egress_only_igw ? 1 : 0
  route_table_id             = aws_route_table.private.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id     = aws_egress_only_internet_gateway.eoigw[0].id
}

# Associate all private subnets to private RT
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
