terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Generate a random string as suffix
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Data Sources
data "aws_availability_zones" "available" {}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

# Local Variables
locals {
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  enable_dns_hostnames = true
  name                 = "cltest"
  private_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region               = "ap-southeast-2"
  vpc_cidr             = "10.0.0.0/16"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"

  azs                  = local.azs
  cidr                 = local.vpc_cidr
  enable_dns_hostnames = local.enable_dns_hostnames
  name                 = local.name
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    name = local.name
  }
}

# Security Group
resource "aws_security_group" "ecs" {
  name   = "${local.name}-ecs"
  vpc_id = module.vpc.vpc_id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow all incoming traffic"
    from_port   = 0
    protocol    = -1
    self        = "false"
    to_port     = 0
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow all outbound traffic"
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  tags = {
    Name = "${local.name}-ecs"
  }
}

# Output suffix for use in tests
output "suffix" {
  value = random_string.suffix.result
}

output "image_id" {
  value = data.aws_ami.ecs_optimized.id
}

output "security_group_id" {
  value = aws_security_group.ecs.id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}
