# modules/bastion/main.tf

resource "aws_security_group" "this" {
  name   = "${var.instance_name}-sg-${var.suffix}"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow SSH from Zscaler"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_nsg_source_prefix
  }

  ingress {
    description = "Allow Ping from peer VPCs"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.allowed_icmp_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
    { Name = "${var.instance_name}-sg" }
  )

}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.this.id]

  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(var.global_tags,
    { Name = var.instance_name }
  )
}