terraform {
  required_version = ">= 1.10, < 2.0"
  backend "s3" {}
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { Project = "hermes-experiment", ManagedBy = "terraform" }
  }
}
data "aws_availability_zones" "available" { state = "available" }
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}
resource "aws_vpc" "hermes" {
  cidr_block           = "10.86.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "hermes-experiment" }
}
resource "aws_subnet" "hermes" {
  vpc_id            = aws_vpc.hermes.id
  cidr_block        = "10.86.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_internet_gateway" "hermes" { vpc_id = aws_vpc.hermes.id }
resource "aws_route_table" "hermes" {
  vpc_id = aws_vpc.hermes.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hermes.id
  }
}
resource "aws_route_table_association" "hermes" {
  subnet_id      = aws_subnet.hermes.id
  route_table_id = aws_route_table.hermes.id
}
resource "aws_security_group" "hermes" {
  name        = "hermes-experiment"
  description = "No inbound access; outbound for SSM, image downloads, and APIs"
  vpc_id      = aws_vpc.hermes.id
}
resource "aws_vpc_security_group_egress_rule" "outbound" {
  security_group_id = aws_security_group.hermes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
resource "aws_iam_role" "host" {
  name = "hermes-experiment-host"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "openai_key" {
  name = "read-openai-key"
  role = aws_iam_role.host.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow", Action = "ssm:GetParameter"
      Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter${var.openai_key_parameter}"
    }]
  })
}
resource "aws_iam_instance_profile" "host" { role = aws_iam_role.host.name }
resource "aws_instance" "hermes" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.hermes.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.hermes.id]
  iam_instance_profile        = aws_iam_instance_profile.host.name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    region = var.aws_region, parameter = var.openai_key_parameter
    image  = var.hermes_image, model = var.openai_model
  })
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  credit_specification { cpu_credits = "standard" }
  tags       = { Name = "hermes-experiment" }
  depends_on = [aws_route_table_association.hermes, aws_vpc_security_group_egress_rule.outbound, aws_iam_role_policy.openai_key, aws_iam_role_policy_attachment.ssm]
}
output "instance_id" { value = aws_instance.hermes.id }
output "aws_region" { value = var.aws_region }
output "connect_command" {
  value = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.hermes.id}"
}
