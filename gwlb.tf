################################################################################
# 8. Create Gateway Load Balancer, Target Group, and VPC Endpoint Service
#    This creates the GWLB in the security VPC and exposes it via an endpoint
#    service so that workload VPCs can route traffic through it.
################################################################################

data "aws_caller_identity" "current" {}

# Create the Gateway Load Balancer
resource "aws_lb" "gwlb" {
  name               = "${var.name_prefix}-gwlb-${random_string.suffix.result}"
  load_balancer_type = "gateway"
  enable_cross_zone_load_balancing = true
  
  # Place the GWLB in the dedicated subnets within the 'vpc_security' VPC
  subnets            = values(module.vpcs["vpc_security"].gwlb_subnet_ids)

  tags = merge(local.global_tags, {
    Name = "${var.name_prefix}-gwlb"
  })
}

# Create the Target Group for the Cloud Connector forwarding interfaces
resource "aws_lb_target_group" "gwlb_tg" {
  name_prefix = "gwlbtg"
  vpc_id      = module.vpcs["vpc_security"].vpc_id
  protocol    = "GENEVE"
  port        = 6081 # Standard GENEVE port
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    port                = var.http_probe_port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = merge(local.global_tags, {
    Name = "${var.name_prefix}-gwlb-tg"
  })
}

# Attach the forwarding IP of each Cloud Connector VM to the Target Group
resource "aws_lb_target_group_attachment" "cc_attachment" {
  # Create a map where keys are the VM index (0, 1, ...) and values are the IPs.
  # The keys are static and known at plan time.
  for_each = {
    for i, ip in module.cc_vm.forwarding_ip : i => ip
  }

  target_group_arn = aws_lb_target_group.gwlb_tg.arn
  # each.value is the IP address from our map.
  target_id        = each.value

}

# Create the VPC Endpoint Service to expose the GWLB
resource "aws_vpc_endpoint_service" "gwlb_service" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(local.global_tags, {
    Name = "${var.name_prefix}-gwlb-service"
  })
}

# Create listener
resource "aws_lb_listener" "gwlb_listener" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb_tg.arn
  }
  tags = merge(local.global_tags, {
    Name = "${var.name_prefix}-gwlb-listener"
  })
}


# Create one VPC Endpoint for EACH private subnet in the security VPC.
resource "aws_vpc_endpoint" "gwlbe_security_vpc" {
  # Iterate over the map of private subnets {az => subnet_id}
  for_each = module.vpcs["vpc_security"].private_subnet_ids

  vpc_id              = module.vpcs["vpc_security"].vpc_id
  service_name        = aws_vpc_endpoint_service.gwlb_service.service_name
  vpc_endpoint_type   = "GatewayLoadBalancer"
  
  # The API requires a list containing exactly ONE subnet ID.
  subnet_ids          = [each.value]

  tags = merge(local.global_tags, {
    # each.key here is the AZ name
    Name = "${var.name_prefix}-gwlbe-vpc-security-${each.key}"
  })
}

# Create a default route in each private route table pointing to the endpoint in the SAME AZ.
resource "aws_route" "security_private_to_gwlbe" {
  # Iterate over the map of private route tables {az => route_table_id}
  for_each = module.vpcs["vpc_security"].private_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  
  # Look up the correct endpoint ID using the AZ key from the loop (each.key).
  # This ensures the route in AZ 'a' points to the endpoint in AZ 'a'.
  vpc_endpoint_id        = aws_vpc_endpoint.gwlbe_security_vpc[each.key].id
}

# (Optional but Recommended) Allow principals to connect to the GWLB service.
# This example allows any principal within your AWS account to connect.
resource "aws_vpc_endpoint_service_allowed_principal" "allow_account" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.gwlb_service.id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}
