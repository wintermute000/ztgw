# modules/flow_logs/outputs.tf

output "flow_log_id" {
  description = "The ID of the created VPC Flow Log."
  value       = aws_flow_log.this.id
}