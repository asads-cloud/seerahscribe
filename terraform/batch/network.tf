# Use default VPC + subnets in eu-west-1
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# SG for Batch instances: all egress, no inbound needed
resource "aws_security_group" "batch_instances" {
  name        = "batch-gpu-sg"
  description = "Security group for AWS Batch GPU instances"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "batch-gpu-sg"
  }
}
