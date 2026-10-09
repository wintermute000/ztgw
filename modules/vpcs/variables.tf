# modules/vpc/variables.tf

variable "vpc_name" {
  description = "The name of the VPC (e.g., 'vpc_security')."
  type        = string
}

variable "vpc_cidr" {
  description = "The main CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "A list of Availability Zone names to deploy subnets into."
  type        = list(string)
}

variable "public_subnets" {
  description = "A list of CIDR blocks for the public subnets, one for each AZ."
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of CIDR blocks for the private subnets, one for each AZ."
  type        = list(string)
}

variable "gwlb_subnets" {
  description = "A list of CIDR blocks for the Gateway Load Balancer subnets, one for each AZ."
  type        = list(string)
}

variable "cc_subnets" {
  description = "An optional list of CIDRs for the CC subnets. If empty, no subnets will be created."
  type        = list(string)
  default     = []
}

variable "suffix" {
  description = "The suffix to assign to the vpc."
  type        = string
}

variable "global_tags" {
  description = "Global tags"
  type        = map(string)
}
