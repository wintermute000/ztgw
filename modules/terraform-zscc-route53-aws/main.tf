################################################################################
# Create Route 53 outbound endpoints per subnet IDs specified
################################################################################
resource "aws_route53_resolver_endpoint" "zpa_r53_ep" {
  name      = "${var.name_prefix}-r53-resolver-ep-${var.resource_tag}"
  direction = "OUTBOUND"

  security_group_ids = var.outbound_endpoint_security_group_ids

  dynamic "ip_address" {
    for_each = var.r53_subnet_ids
    iterator = subnet_id

    content {
      subnet_id = subnet_id.value
    }
  }

  tags = merge(var.global_tags,
    { Name = "${var.name_prefix}-r53-resolver-ep-${var.resource_tag}" }
  )
}


################################################################################
# Create Route 53 resolver rule to steer ZPA desired domain requests to 
# Cloud Connector per map for variable "domain_names"
################################################################################
resource "aws_route53_resolver_rule" "fwd_to_cc" {
  for_each             = var.domain_names
  domain_name          = each.value
  name                 = "${var.name_prefix}-r53-rule-${each.key}-${var.resource_tag}"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.zpa_r53_ep.id

  dynamic "target_ip" {
    for_each = var.target_address

    content {
      ip = target_ip.value
    }
  }

  tags = merge(var.global_tags,
    { Name = "${var.name_prefix}-r53-rules-${each.key}-${var.resource_tag}" }
  )
}

# Forward rules are deliberately NOT associated with the endpoint (security) VPC.
# The Cloud Connectors resolve non-ZPA names upstream via that VPC's resolver,
# and App Connectors there must get real IPs - associating the rules would loop
# queries back to the CCs / hand ACs synthetic ZPA answers. The outbound endpoint
# does not need its own VPC associated for the rules to work in the spokes.

# Associate with spoke VPCs
# --- STEP 1: PREPARE THE "TO-DO LIST" (The Nested Loop) as Terraform won't allow nested for_each loops to create resources ---
locals {
  # This block prepares a single list of all the rule-to-VPC pairs we need.
  # It reads just like a nested loop:
  # "For each rule... and for each spoke VPC... create a pair."
  spoke_association_pairs_domainrules = flatten([
    for rule_key in keys(var.domain_names) : [
      for vpc_id in var.spoke_vpc_ids : {
        rule_key = rule_key
        vpc_id   = vpc_id
      }
    ]
  ])
}

# --- STEP 2: CREATE THE RESOURCES (The Single Loop) ---
resource "aws_route53_resolver_rule_association" "spoke_associations_domainrules" {
  # Now we just loop over the simple "to-do list" we prepared above.
  for_each = { for i, pair in local.spoke_association_pairs_domainrules : i => pair }

  # For each item in the list, create an association.
  resolver_rule_id = aws_route53_resolver_rule.fwd_to_cc[each.value.rule_key].id
  vpc_id           = each.value.vpc_id
}


################################################################################
# Create Route 53 resolver rules to have AWS recursively resolve Zscaler 
# domains directly rather than send to Cloud Connector
################################################################################
resource "aws_route53_resolver_rule" "system" {
  for_each    = var.zscaler_domains
  domain_name = each.value
  name        = "${var.name_prefix}-r53-system-rule-${each.key}-${var.resource_tag}"
  rule_type   = "SYSTEM"

  tags = merge(var.global_tags,
    { Name = "${var.name_prefix}-r53-rules-${each.key}-${var.resource_tag}" }
  )
}

# Associate Route 53 System Resolver rules to VPC
resource "aws_route53_resolver_rule_association" "r53_rule_association_system" {
  for_each         = var.zscaler_domains
  resolver_rule_id = aws_route53_resolver_rule.system[each.key].id
  vpc_id           = var.vpc_id
}

# Associate with spoke VPCs
# --- STEP 1: PREPARE THE "TO-DO LIST" (The Nested Loop) as Terraform won't allow nested for_each loops to create resources ---
locals {
  # This block prepares a single list of all the rule-to-VPC pairs we need.
  # It reads just like a nested loop:
  # "For each rule... and for each spoke VPC... create a pair."
  spoke_association_pairs_zrules = flatten([
    for rule_key in keys(var.zscaler_domains) : [
      for vpc_id in var.spoke_vpc_ids : {
        rule_key = rule_key
        vpc_id   = vpc_id
      }
    ]
  ])
}

# --- STEP 2: CREATE THE RESOURCES (The Single Loop) ---
resource "aws_route53_resolver_rule_association" "spoke_associations_zrules" {
  # Now we just loop over the simple "to-do list" we prepared above.
  for_each = { for i, pair in local.spoke_association_pairs_zrules : i => pair }

  # For each item in the list, create an association.
  resolver_rule_id = aws_route53_resolver_rule.system[each.value.rule_key].id
  vpc_id           = each.value.vpc_id
}


