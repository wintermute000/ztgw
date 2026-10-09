# modules/tgw/variables.tf

variable "vpcs_to_attach" {
  description = "A map of VPC data required to create attachments and routes."
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
    cidr_block = string

    public_route_table_id   = string
    private_route_table_ids = map(string)
    gwlb_route_table_ids    = map(string)
    cc_route_table_ids      = map(string)
  }))
}

variable "summary_cidr_block" {
  description = "The summary CIDR block for inter-VPC TGW routes."
  type        = string
}

variable "global_tags" {
  description = "Global tags"
  type        = map(string)
}