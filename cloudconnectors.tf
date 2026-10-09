################################################################################
# Create the user_data file with necessary bootstrap variables for Cloud 
# Connector
################################################################################
# 
locals {
  ccuserdata = <<USERDATA
[ZSCALER]
CC_URL=${var.cc_vm_prov_url}
SECRET_NAME=${var.secret_name}
HTTP_PROBE_PORT=${var.http_probe_port}
USERDATA
}

# Write the file to local filesystem for storage/reference
resource "local_file" "ccuser_data_file" {
  content  = local.ccuserdata
  filename = "../ccuser_data"
}


################################################################################
# Locate Latest CC AMI by product code
################################################################################
data "aws_ami" "cloudconnector" {
  most_recent = true

  filter {
    name   = "product-code"
    values = var.aws_region == "cn-north-1" || var.aws_region == "cn-northwest-1" ? ["axnpwhsb4facossmbm1h9yad6"] : ["2l8tfysndbav4tv2nfjwak3cu"]
    #change product code value for China marketplace
  }

  owners = ["aws-marketplace"]
}


################################################################################
# Create Cloud Connectors only in Security VPC
################################################################################
module "cc_vm" {
  source                             = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-ccvm-aws"
  cc_count                           = var.num_azs
  ami_id                             = contains(var.ccami_id, "") ? [data.aws_ami.cloudconnector.id] : var.ami_id
  name_prefix                        = var.name_prefix
  resource_tag                       = random_string.suffix.result
  global_tags                        = local.global_tags
  mgmt_subnet_id                     = values(module.vpcs["vpc_security"].cc_subnet_ids)
  service_subnet_id                  = values(module.vpcs["vpc_security"].cc_subnet_ids)
  instance_key                       = var.key_name
  user_data                          = local.ccuserdata
  ccvm_instance_type                 = var.ccvm_instance_type
  cc_instance_size                   = var.cc_instance_size
  iam_instance_profile               = module.cc_iam.iam_instance_profile_id
  mgmt_security_group_id             = module.cc_sg.mgmt_security_group_id
  service_security_group_id          = module.cc_sg.service_security_group_id
  ebs_volume_type                    = var.ebs_volume_type
  ebs_encryption_enabled             = var.ebs_encryption_enabled
  byo_kms_key_alias                  = var.byo_kms_key_alias
  hostname_type                      = var.hostname_type
  resource_name_dns_a_record_enabled = var.resource_name_dns_a_record_enabled



  depends_on = [
    null_resource.cc_error_checker
  ]
}

################################################################################
# 5. Create IAM Policy, Roles, and Instance Profiles to be assigned to CC. 
#    Default behavior will create 1 of each IAM resource per CC VM. Set variable 
#    "reuse_iam" to true if you would like a single IAM profile created and 
#    assigned to ALL Cloud Connectors instead.
################################################################################
module "cc_iam" {
  source             = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-iam-aws"
  iam_count          = var.reuse_iam == false ? var.cc_count : 1
  name_prefix        = var.name_prefix
  resource_tag       = random_string.suffix.result
  global_tags        = local.global_tags
  secret_name        = var.secret_name
  cloud_tags_enabled = var.cloud_tags_enabled
}


################################################################################
# 6. Create Security Group and rules to be assigned to CC mgmt and and service 
#    interface(s). Default behavior will create 1 of each SG resource per CC VM. 
#    Set variable "reuse_security_group" to true if you would like a single 
#    security group created and assigned to ALL Cloud Connectors instead.
################################################################################
module "cc_sg" {
  source                   = "../terraform-aws-cloud-connector-modules/modules/terraform-zscc-sg-aws"
  sg_count                 = var.reuse_security_group == false ? var.cc_count : 1
  name_prefix              = var.name_prefix
  resource_tag             = random_string.suffix.result
  global_tags              = local.global_tags
  vpc_id                   = module.vpcs["vpc_security"].vpc_id
  zpa_enabled              = var.zpa_enabled
  http_probe_port          = var.http_probe_port
  mgmt_ssh_enabled         = var.mgmt_ssh_enabled
  gwlb_enabled             = false
  all_ports_egress_enabled = var.all_ports_egress_enabled
  support_access_enabled   = var.support_access_enabled
  zssupport_server         = var.zssupport_server
}


################################################################################
# 7. Create Route 53 Resolver Rules and Endpoints for utilization with DNS 
#    redirection to facilitate Cloud Connector ZPA service.
################################################################################

locals {
  # 1. Construct the LIST of spoke VPC IDs directly from the VPC module's output.
  #    Note: central VPC must be named vpc_security
  spoke_vpc_ids = [
    for key, vpc in module.vpcs : vpc.vpc_id
    if key != "vpc_security"
  ]
}

module "route53" {
  source                               = "./modules/terraform-zscc-route53-aws"
  name_prefix                          = var.name_prefix
  resource_tag                         = random_string.suffix.result
  global_tags                          = local.global_tags
  vpc_id                               = module.vpcs["vpc_security"].vpc_id
  r53_subnet_ids                       = values(module.vpcs["vpc_security"].cc_subnet_ids)
  outbound_endpoint_security_group_ids = module.cc_sg.outbound_endpoint_security_group_id
  domain_names                         = var.domain_names
  target_address                       = module.cc_vm.forwarding_ip
  spoke_vpc_ids                        = local.spoke_vpc_ids
  depends_on = [module.cc_vm]
}


################################################################################
# Validation for Cloud Connector instance size and EC2 Instance Type 
# compatibilty. Terraform does not have a good/native way to raise an error at 
# the moment, so this will trigger off an invalid count value if there is an 
# improper deployment configuration.
################################################################################
resource "null_resource" "cc_error_checker" {
  count = local.valid_cc_create ? 0 : "Cloud Connector parameters were invalid. No appliances were created. Please check the documentation and cc_instance_size / ccvm_instance_type values that were chosen" # 0 means no error is thrown, else throw error
  provisioner "local-exec" {
    command = <<EOF
      echo "Cloud Connector parameters were invalid. No appliances were created. Please check the documentation and cc_instance_size / ccvm_instance_type values that were chosen" >> ../errorlog.txt
    EOF
  }
}
