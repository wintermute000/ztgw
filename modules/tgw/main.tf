# modules/tgw/main.tf

# --- TGW Resource Creation and TGW-Side Routing  ---
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Main Transit Gateway for inter-VPC communication"
  #Disable explicit association and propagation
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = { Name = "main-tgw" }
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "main-tgw-rt" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each           = var.vpcs_to_attach
  subnet_ids         = each.value.subnet_ids
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  #Conditionally enable appliance mode ONLY for the security VPC attachment.
  appliance_mode_support = each.key == "vpc_security" ? "enable" : "disable"
  #Disable explicit association and propagation
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags               = { Name = "${each.key}-tgw-attachment" }
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each                       = aws_ec2_transit_gateway_vpc_attachment.this
  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each                       = aws_ec2_transit_gateway_vpc_attachment.this
  transit_gateway_attachment_id  = each.value.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}

# --- Default Route in TGW route table to Security VPC  ---

resource "aws_ec2_transit_gateway_route" "default_to_security_vpc" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
  
  # This targets the specific attachment created for the 'vpc_security' VPC
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this["vpc_security"].id

  depends_on = [
    aws_ec2_transit_gateway_route_table_association.this
  ]
}

# --- VPC-Side Routing (Client-Side) ---

# This block  uses flatten() to create a simple list of objects,
# one for each route table that needs a summary route. This is the standard pattern
# for handling nested loops for for_each.
locals {
  # Example output: { "vpc_1-priv-0" = "rtb-id-1", "vpc_1-priv-1" = "rtb-id-2", ... }
  # All private route tables except for security vpc
  workload_private_route_tables_map = {
    for pair in flatten([
      for vpc_key, vpc_data in var.vpcs_to_attach : [
        for rt_key, rt_id in vpc_data.private_route_table_ids : {
          unique_key = "${vpc_key}-priv-${rt_key}"
          rt_id      = rt_id
        }
      ] if vpc_key != "vpc_security" # <--  This condition filters out the security VPC.
    ]) : pair.unique_key => pair.rt_id
  }

  all_private_route_tables_map = {
    for pair in flatten([
      for vpc_key, vpc_data in var.vpcs_to_attach : [
        for rt_key, rt_id in vpc_data.private_route_table_ids : {
          unique_key = "${vpc_key}-priv-${rt_key}"
          rt_id      = rt_id
        }
      ] 
    ]) : pair.unique_key => pair.rt_id
  }

  all_gwlb_route_tables_map = {
    for pair in flatten([
      for vpc_key, vpc_data in var.vpcs_to_attach : [
        for rt_key, rt_id in vpc_data.gwlb_route_table_ids : {
          unique_key = "${vpc_key}-gwlb-${rt_key}"
          rt_id      = rt_id
        }
      ]
    ]) : pair.unique_key => pair.rt_id
  }

  all_cc_route_tables_map = {
    for pair in flatten([
      for vpc_key, vpc_data in var.vpcs_to_attach : [
        for rt_key, rt_id in vpc_data.cc_route_table_ids : {
          unique_key = "${vpc_key}-cc-${rt_key}"
          rt_id      = rt_id
        }
      ]
    ]) : pair.unique_key => pair.rt_id
  }
}

# --- Add one summary route to each PUBLIC route table ---
resource "aws_route" "summary_public" {
  for_each = var.vpcs_to_attach

  route_table_id         = each.value.public_route_table_id
  destination_cidr_block = var.summary_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# --- Add one summary route to all PRIVATE route table ---
resource "aws_route" "summary_private" {
  for_each = local.all_private_route_tables_map

  # each.value now directly refers to the route table ID
  route_table_id         = each.value
  destination_cidr_block = var.summary_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# --- Add default route to workload PRIVATE route table to use TGW ---
resource "aws_route" "default_private" {
  for_each = local.workload_private_route_tables_map

  # each.value now directly refers to the route table ID
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}


# --- Add one summary route to each GWLB route table ---
resource "aws_route" "summary_gwlb" {
  for_each = local.all_gwlb_route_tables_map

  route_table_id         = each.value
  destination_cidr_block = var.summary_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# --- Add one summary route to each CC route table ---
resource "aws_route" "summary_cc" {
  for_each = local.all_cc_route_tables_map

  route_table_id         = each.value
  destination_cidr_block = var.summary_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.this.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.this]
}

