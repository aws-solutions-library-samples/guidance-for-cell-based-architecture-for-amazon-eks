provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
#  name   = basename(path.cwd)
  name   = "eks-cell"
  region = "us-west-2"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

################################################################################
# VPC
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}
#--------------------------------------------------------------
# Adding guidance solution ID via AWS CloudFormation resource
#--------------------------------------------------------------
resource "random_bytes" "this" {
  length = 2
}
resource "aws_cloudformation_stack" "guidance_deployment_metrics" {
  name          = "tracking-stack-${random_bytes.this.hex}"
  on_failure    = "DO_NOTHING"
  template_body = <<STACK
    {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "RB - This is Guidance for a Cell-Based Architecture for Amazon EKS on AWS (SXXXXX)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}