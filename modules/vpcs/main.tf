# modules/vpc/main.tf

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-vpc-${var.suffix}" }
  )

}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-igw" }
}
# Explicitly declare routes instead of entire route table so that routes can be added in TGW modules
# --- Multi-AZ Public Subnets and single shared Route Table ---
resource "aws_subnet" "public" {
  for_each = { for i, cidr in var.public_subnets : i => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = var.availability_zones[each.key]
  map_public_ip_on_launch = true
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-public-subnet-${var.availability_zones[each.key]}" }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# --- Multi-AZ NAT Gateways (One per AZ) ---
resource "aws_eip" "nat" {
  for_each   = toset(var.availability_zones)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-nat-eip-${each.value}"  }
  )
}

resource "aws_nat_gateway" "this" {
  for_each      = { for i, az in var.availability_zones : i => az }
  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.key].id
  tags = merge(var.global_tags,
    {  Name = "${var.vpc_name}-nat-gw-${each.value}"  }
  )
}

# --- Multi-AZ Private Subnets and Per-AZ Routing ---
resource "aws_subnet" "private" {
  for_each = { for i, cidr in var.private_subnets : i => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key]
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-private-subnet-${var.availability_zones[each.key]}"  }
  )
}

resource "aws_route_table" "private" {
  for_each = { for i, az in var.availability_zones : i => az }
  vpc_id   = aws_vpc.this.id
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-private-rt-${each.value}"  }
  )
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# --- Multi-AZ GWLB Subnets and Per-AZ Routing ---
resource "aws_subnet" "gwlb" {
  for_each          = { for i, cidr in var.gwlb_subnets : i => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key]
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-gwlb-subnet-${var.availability_zones[each.key]}" }
  )
}

resource "aws_route_table" "gwlb" {
  for_each = { for i, az in var.availability_zones : i => az }
  vpc_id   = aws_vpc.this.id
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-gwlb-rt-${each.value}" }
  )
}

resource "aws_route" "gwlb_default" {
  for_each = { for i, az in var.availability_zones : i => az }
  route_table_id         = aws_route_table.gwlb[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "gwlb" {
  for_each       = aws_subnet.gwlb
  subnet_id      = each.value.id
  route_table_id = aws_route_table.gwlb[each.key].id
}

# --- Multi-AZ Optional CC Subnets and Per-AZ Routing ---
resource "aws_subnet" "cc" {
  for_each          = { for i, cidr in var.cc_subnets : i => cidr }
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = var.availability_zones[each.key]
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-cc-subnet-${var.availability_zones[each.key]}"  }
  )
}

resource "aws_route_table" "cc" {
  for_each = { for i, az in var.availability_zones : i => az }
  vpc_id   = aws_vpc.this.id
  tags = merge(var.global_tags,
    { Name = "${var.vpc_name}-cc-rt-${each.value}" }
  )
}

resource "aws_route" "cc_default" {
  for_each = { for i, az in var.availability_zones : i => az }
  route_table_id         = aws_route_table.cc[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "cc" {
  for_each       = aws_subnet.cc
  subnet_id      = each.value.id
  route_table_id = aws_route_table.cc[each.key].id
}