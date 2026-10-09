# ./outputs.tf

output "vpc_details" {
  description = "A map containing detailed information for each created VPC."
  value = {
    # Loop through the map of VPC modules created in main.tf
    for vpc_name, vpc_module in module.vpcs : vpc_name => {
      vpc_id                  = vpc_module.vpc_id
      vpc_cidr_block          = vpc_module.vpc_cidr_block
      internet_gateway_id     = vpc_module.internet_gateway_id
      nat_gateway_public_ips  = vpc_module.public_nat_gateway_public_ips
      public_subnets = {
        ids   = vpc_module.public_subnet_ids
        cidrs = vpc_module.public_subnet_cidrs
      }
      private_subnets = {
        ids   = vpc_module.private_subnet_ids
        cidrs = vpc_module.private_subnet_cidrs
      }
      gwlb_subnets = {
        ids   = vpc_module.gwlb_subnet_ids
        cidrs = vpc_module.gwlb_subnet_cidrs
      }
      cc_subnets = {
        ids   = vpc_module.cc_subnet_ids
        cidrs = vpc_module.cc_subnet_cidrs
      }
    }
  }
}

output "bastion_details" {
  description = "Public IP, Private IP, and SSH command for each bastion instance."
  value = {
    for name, bastion in module.bastions : name => {
      public_ip  = bastion.public_ip
      private_ip = bastion.private_ip
      ssh_command = "ssh -i ~/.ssh/${var.key_name} ec2-user@${bastion.public_ip}"
    }
  }
}

output "cloud_connector_details_by_az" {
  description = "A map of all Cloud Connector VMs with their ID, Management IP, and Forwarding IP, keyed by Availability Zone."
  
  value = {
    # We will loop using an index 'i' from 0 up to the number of VMs created.
    # We use length() on one of the lists (e.g., id) to determine how many times to loop.
    for i in range(length(module.cc_vm.id)) :

    # The key for our map will be the Availability Zone at the current index 'i'.
    module.cc_vm.availability_zone[i] => {

      # The value will be an object containing the details from the other
      # lists, all referenced using the same index 'i'.
      id            = module.cc_vm.id[i]
      management_ip = module.cc_vm.management_ip[i]
      forwarding_ip = module.cc_vm.forwarding_ip[i]
    }
  }
}

output "workload_vms" {
  description = "A map of the created workload EC2 instances, keyed by their Availability Zone."
  value = {
    # We use a 'for' expression to loop through the map of instances created by the 'aws_instance.workloads' resource.
    # 'az' will be the key (e.g., "ap-southeast-2a"), and 'vm' will be the full instance object.
    for az, vm in aws_instance.workloads : az => {
      instance_id       = vm.id
      private_ip        = vm.private_ip
      public_ip         = vm.public_ip
      arn               = vm.arn
      availability_zone = vm.availability_zone
    }
  }
}

output "gwlb_service_name" {
  description = "The service name of the Gateway Load Balancer VPC Endpoint Service."
  value       = aws_vpc_endpoint_service.gwlb_service.service_name
}

output "transit_gateway_details" {
  description = "Details of the centralized Transit Gateway"
  value = {
    id                         = module.transit_gateway.transit_gateway_id
    arn                        = module.transit_gateway.transit_gateway_arn 
    route_table                = module.transit_gateway.transit_gateway_route_table_id
  }
}

output "transit_gateway_attachment_ids" {
  description = "A list of the Transit Gateway VPC attachment IDs."
  value       = module.transit_gateway.vpc_attachment_ids
}

output "gwlb" {
  description = "GWLB details"
  value = {
    gwlb_name       = aws_lb.gwlb.name
    gwlb_subnets    = aws_lb.gwlb.subnets
  }
}

output "gwlb_target_group" {
  value = {
    gwlb_target_group_name = aws_lb_target_group.gwlb_tg.name
  }
}

output "gwlb_target_group_attachment" {
  value = aws_lb_target_group_attachment.cc_attachment
}

output "gwlb_endpoints" {
  value = {
    # This loops through the original map, preserving the keys
    for key, endpoint in aws_vpc_endpoint.gwlbe_security_vpc : key => {
      id                   = endpoint.id
      subnet_configuration = endpoint.subnet_configuration
      enis                 = endpoint.network_interface_ids
    }
  }
}

