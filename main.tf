# ./main.tf

provider "aws" {
  region = var.aws_region
}

################################################################################
# Generate a unique random string for resource name assignment and key pair
################################################################################
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

################################################################################
# Map default tags with values to be assigned to all tagged resources
################################################################################
locals {
  global_tags = {
    Owner                                                                                = var.owner_tag
    ManagedBy                                                                            = "terraform"
    Environment = "${var.name_prefix}-${random_string.suffix.result}"
  }
}

# --- Data Sources to get AZs and AMI ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# --- Random Provider to select one AZ per VPC for bastion placement ---
resource "random_integer" "bastion_az_index" {
  for_each = var.vpcs
  min      = 0
  max      = var.num_azs - 1
}

# --- IAM and CloudWatch for Flow Logs (Unchanged) ---
resource "aws_iam_role" "vpc_flow_log_role" {
  name = "vpc-flow-log-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" } }]
  })
}

data "aws_iam_policy_document" "flow_log_policy_doc" {
  statement {
    effect = "Allow"

    # These are the minimum permissions required for the service to write logs.
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]

    # This is a key part of least privilege: the policy only applies to the
    # specific log group created by Terraform, not all log groups in the account.
    resources = [
      "${aws_cloudwatch_log_group.flow_log_group.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "flow_log_policy" {
  name        = "vpc-flow-logs-to-cloudwatch-policy"
  description = "Allows VPC Flow Logs to write to a specific CloudWatch Log Group."
  policy      = data.aws_iam_policy_document.flow_log_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_policy_attach" {
  role       = aws_iam_role.vpc_flow_log_role.name
  policy_arn = aws_iam_policy.flow_log_policy.arn
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  # The name is now sourced from the new variable instead of being hardcoded.
  name = var.flow_log_group_name
}


# --- Main Module Calls ---

module "vpcs" {
  for_each = var.vpcs
  source   = "./modules/vpcs"

  vpc_name           = each.key
  vpc_cidr           = each.value.cidr_block
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.num_azs)
  suffix             = random_string.suffix.result
  public_subnets  = each.value.public_subnets
  private_subnets = each.value.private_subnets
  gwlb_subnets    = each.value.gwlb_subnets
  cc_subnets = coalesce(each.value.cc_subnets, [])
  global_tags        = local.global_tags
}

# --- Locals block to prepare data for a single bastion per VPC ---
locals {
  bastion_hosts = {
    for vpc_key, vpc_output in module.vpcs :
    vpc_key => {
      vpc_id    = vpc_output.vpc_id
      subnet_id = vpc_output.public_subnet_ids[tostring(random_integer.bastion_az_index[vpc_key].result)]
    }
  }
}

# --- Bastion Module Call (creates one bastion per VPC) ---
module "bastions" {
  for_each           = local.bastion_hosts
  source             = "./modules/bastions"
  instance_name      = "${var.name_prefix}-bastion-${each.key}-${random_string.suffix.result}"
  vpc_id             = each.value.vpc_id
  public_subnet_id   = each.value.subnet_id
  key_name           = var.key_name
  instance_type      = var.instance_type
  ami_id             = data.aws_ami.amazon_linux_2.id
  allowed_icmp_cidrs = [for vpc in var.vpcs : vpc.cidr_block]
  suffix             = random_string.suffix.result
  global_tags        = local.global_tags
}

# --- Transit Gateway Module Call (updated for multi-AZ) ---
module "transit_gateway" {
  source = "./modules/tgw"
  summary_cidr_block = var.summary_cidr_block
  vpcs_to_attach = {
    for k, v in module.vpcs : k => {
      vpc_id     = v.vpc_id
      subnet_ids = values(v.private_subnet_ids)
      cidr_block = var.vpcs[k].cidr_block
      public_route_table_id   = v.public_route_table_id
      private_route_table_ids = v.private_route_table_ids
      gwlb_route_table_ids    = v.gwlb_route_table_ids
      cc_route_table_ids      = v.cc_route_table_ids
    }
  }
  global_tags        = local.global_tags
}

# --- Flow Logs Module Call ---
module "flow_logs" {
  for_each = module.vpcs
  source   = "./modules/flow_logs"

  vpc_id        = each.value.vpc_id
  iam_role_arn  = aws_iam_role.vpc_flow_log_role.arn
  log_group_arn = aws_cloudwatch_log_group.flow_log_group.arn
  dependencies  = [aws_iam_role_policy_attachment.vpc_flow_log_policy_attach]
}