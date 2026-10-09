# modules/bastion/variables.tf


variable "bastion_nsg_source_prefix" {
  type        = list(string)
  description = "CIDR blocks of trusted networks for bastion host ssh access"
  default     = [
  "58.220.95.0/24",
  "64.215.22.0/24",
  "87.58.64.0/18",
  "94.188.131.0/25",
  "94.188.139.64/26",
  "94.188.248.64/26",
  "98.98.26.0/24",
  "98.98.27.0/24",
  "98.98.28.0/24",
  "101.2.192.0/18",
  "104.129.192.0/20",
  "112.137.170.0/24",
  "124.248.141.0/24",
  "128.177.125.0/24",
  "136.226.0.0/16",
  "137.83.128.0/18",
  "140.210.152.0/23",
  "147.161.128.0/17",
  "154.113.23.0/24",
  "165.225.0.0/17",
  "165.225.192.0/18",
  "167.103.0.0/16",
  "170.85.0.0/16",
  "185.46.212.0/22",
  "194.9.96.0/20",
  "194.9.112.0/22",
  "194.9.116.0/24",
  "196.23.154.64/27",
  "196.23.154.96/27",
  "197.98.201.0/24",
  "197.156.241.224/27",
  "198.14.64.0/18",
  "199.168.148.0/23",
  "209.55.128.0/18",
  "209.55.192.0/19",
  "211.144.19.0/24",
  "220.243.154.0/23",
  "221.122.91.0/24",
  "205.220.0.0/17",
  "167.106.0.0/16",
  "103.215.126.0/24",
  "159.254.0.0/16",
  "98.98.186.0/24",
  "98.98.187.0/24",
  "98.98.169.0/24",
  "175.107.128.0/18",
  "137.31.0.0/16"
]
}

variable "instance_name" {
  description = "The name to assign to the EC2 instance."
  type        = string
}

variable "suffix" {
  description = "The suffix to assign to the EC2 instance."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the instance will be deployed."
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the subnet where the instance will be deployed."
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 Key Pair to use for SSH access."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type (e.g., 't2.micro')."
  type        = string
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the instance."
  type        = string
}

variable "allowed_icmp_cidrs" {
  description = "A list of CIDR blocks from which to allow ICMP (ping) traffic."
  type        = list(string)
}

variable "global_tags" {
  description = "Global tags"
  type        = map(string)
}