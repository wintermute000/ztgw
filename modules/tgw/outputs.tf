# modules/tgw/outputs.tf

output "transit_gateway_id" {
  description = "The ID of the created Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "The ARN of the created Transit Gateway."
  value       = aws_ec2_transit_gateway.this.arn
}

output "transit_gateway_route_table_id" {
  description = "The ID of the explicitly created Transit Gateway Route Table."
  value       = aws_ec2_transit_gateway_route_table.main.id
}

output "vpc_attachment_ids" {
  description = "A map of the TGW VPC attachments, keyed by VPC ID, including attachment and subnet IDs."
  value = {
    for vpc_id, attachment in aws_ec2_transit_gateway_vpc_attachment.this : vpc_id => {
      id         = attachment.id
      subnet_ids = attachment.subnet_ids
    }
  }
}

