provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}

locals {
#  name   = basename(path.cwd)
  name   = "eks-cell"
  region = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  # Cell names for consistent naming across resources
  cell1_name = format("%s-%s", local.name, "az1")
  cell2_name = format("%s-%s", local.name, "az2")
  cell3_name = format("%s-%s", local.name, "az3")

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

  # Add per-subnet tags for Karpenter discovery
  private_subnet_tags_per_az = {
    (local.azs[0]) = {
      "karpenter.sh/discovery" = local.cell1_name
    }
    (local.azs[1]) = {
      "karpenter.sh/discovery" = local.cell2_name
    }
    (local.azs[2]) = {
      "karpenter.sh/discovery" = local.cell3_name
    }
  }

  tags = local.tags
}

# Add Karpenter discovery tags to EKS cluster security groups
resource "aws_ec2_tag" "cluster_sg_karpenter_tags_cell1" {
  resource_id = module.eks_cell1.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell1_name
  
  depends_on = [module.eks_cell1]
}

resource "aws_ec2_tag" "cluster_sg_karpenter_tags_cell2" {
  resource_id = module.eks_cell2.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell2_name
  
  depends_on = [module.eks_cell2]
}

resource "aws_ec2_tag" "cluster_sg_karpenter_tags_cell3" {
  resource_id = module.eks_cell3.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell3_name
  
  depends_on = [module.eks_cell3]
}

# Add Karpenter discovery tags to node security groups
resource "aws_ec2_tag" "node_sg_karpenter_tags_cell1" {
  resource_id = module.eks_cell1.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell1_name
  
  depends_on = [module.eks_cell1]
}

resource "aws_ec2_tag" "node_sg_karpenter_tags_cell2" {
  resource_id = module.eks_cell2.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell2_name
  
  depends_on = [module.eks_cell2]
}

resource "aws_ec2_tag" "node_sg_karpenter_tags_cell3" {
  resource_id = module.eks_cell3.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cell3_name
  
  depends_on = [module.eks_cell3]
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
        "Description": "RB - This is Guidance for a Cell-Based Architecture for Amazon EKS on AWS (SO9303)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}