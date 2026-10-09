# modules/flow_logs/main.tf

resource "aws_flow_log" "this" {
  # The depends_on is passed from the root module to ensure the IAM role has
  # its policy attached before this resource is created.
  depends_on = [var.dependencies]

  log_destination      = var.log_group_arn
  iam_role_arn         = var.iam_role_arn
  traffic_type         = "ALL"
  vpc_id               = var.vpc_id
}