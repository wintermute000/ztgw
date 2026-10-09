# modules/flow_logs/variables.tf

variable "vpc_id" {
  description = "The ID of the VPC to enable flow logs for."
  type        = string
}

variable "iam_role_arn" {
  description = "ARN of the IAM role for VPC Flow Logs."
  type        = string
}

variable "log_group_arn" {
  description = "ARN of the CloudWatch Log Group to send logs to."
  type        = string
}

variable "dependencies" {
  description = "A list of dependencies to wait for before creating the flow log."
  type        = any
  default     = []
}