################################################################################
# Create a flattened map of all instances to be deployed across all specified
# VPCs and their private subnets, excluding the security VPC.
################################################################################
locals {
  instances_to_create = merge(
    [
      for vpc_key, vpc_instance in module.vpcs : {
        for i, private_subnet_id in vpc_instance.private_subnet_ids :
          # CORRECTED: Changed vpc_instance.num_azs to vpc_instance.azs
          "${vpc_key}-${vpc_instance.availability_zones[i]}" => {
            vpc_key   = vpc_key
            vpc_id    = vpc_instance.vpc_id
            vpc_cidr  = module.vpcs[vpc_key].vpc_cidr_block
            subnet_id = private_subnet_id
            # CORRECTED: Changed vpc_instance.num_azs to vpc_instance.azs
            az        = vpc_instance.availability_zones[i]
          }
      } if vpc_key != "vpc_security"
    ]...
  )
}

################################################################################
# Pull Amazon Linux 2023 AMI for instance use
################################################################################
data "aws_ssm_parameter" "amazon_linux_latest" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

################################################################################
# Create one Security Group per target VPC (excluding vpc_security)
################################################################################
resource "aws_security_group" "workload" {
  # Use for_each to create a security group in each VPC except vpc_security
  for_each = {
    # CORRECTED: The loop variable for the key is 'k', not 'vpc_key'
    for k, v in module.vpcs : k => v if k != "vpc_security"
  }

  name        = "${var.name_prefix}-workload-sg-${each.key}-${random_string.suffix.result}"
  description = "Allow SSH and outbound access for ${each.key}"
  vpc_id      = each.value.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.global_tags,
    { Name = "${var.name_prefix}-workload-sg-${each.key}" }
  )
}

# No changes needed in the rules below
resource "aws_security_group_rule" "ftp" {
  for_each          = aws_security_group.workload
  protocol          = "TCP"
  from_port         = 21
  to_port           = 21
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "ssh" {
  for_each          = aws_security_group.workload
  protocol          = "TCP"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "http" {
  for_each          = aws_security_group.workload
  protocol          = "TCP"
  from_port         = 80
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "https" {
  for_each          = aws_security_group.workload
  protocol          = "TCP"
  from_port         = 443
  to_port           = 443
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "ping" {
  for_each          = aws_security_group.workload
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "ingress"
  cidr_blocks       = var.workload_nsg_source_prefix
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "internet" {
  for_each          = aws_security_group.workload
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = each.value.id
}

resource "aws_security_group_rule" "intranet" {
  for_each          = aws_security_group.workload
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  type              = "egress"
  cidr_blocks       = [module.vpcs[each.key].vpc_cidr_block]
  security_group_id = each.value.id
}


################################################################################
# IAM Resources
################################################################################
data "aws_iam_policy_document" "workloads_instance_assume_role_policy" {
  version = "2012-10-17"
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workloads_iam_role" {
  name               = "${var.name_prefix}-workloads-iam-role-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.workloads_instance_assume_role_policy.json
  tags               = merge(var.global_tags)
}

# CORRECTED: The variable was undeclared, so we hardcode the known AWS-managed policy name.
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.workloads_iam_role.name
}

resource "aws_iam_instance_profile" "workloads_host_profile" {
  name = "${var.name_prefix}-workloads-host-profile-${random_string.suffix.result}"
  role = aws_iam_role.workloads_iam_role.name
  tags = merge(var.global_tags)
}

################################################################################
# Create EC2 hosts in every private subnet of all VPCs except vpc_security
################################################################################
resource "aws_instance" "workloads" {
  for_each = local.instances_to_create

  ami                         = data.aws_ssm_parameter.amazon_linux_latest.value
  instance_type               = var.workload_instance_type
  key_name                    = var.key_name
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = [aws_security_group.workload[each.value.vpc_key].id]
  iam_instance_profile        = aws_iam_instance_profile.workloads_host_profile.name
  associate_public_ip_address = false
  user_data = file("./workloads-user-data")
  lifecycle {
    ignore_changes = [ami]
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.global_tags,
    { Name = "${var.name_prefix}-workload-${each.key}-${random_string.suffix.result}" },
    { workload_az = each.key},
  )
}