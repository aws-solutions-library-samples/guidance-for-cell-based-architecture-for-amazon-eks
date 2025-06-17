################################################################################
# AWS Load Balancer Controller Configuration
################################################################################

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create IAM roles directly instead of using the module
resource "aws_iam_role" "lb_controller_role_cell1" {
  name = "${local.cell1_name}-lb-controller"
  
  # Explicitly define the trust relationship
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cell1.oidc_provider, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks_cell1.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller-sa"
            "${replace(module.eks_cell1.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "lb_controller_role_cell2" {
  name = "${local.cell2_name}-lb-controller"
  
  # Explicitly define the trust relationship
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cell2.oidc_provider, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks_cell2.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller-sa"
            "${replace(module.eks_cell2.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role" "lb_controller_role_cell3" {
  name = "${local.cell3_name}-lb-controller"
  
  # Explicitly define the trust relationship
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cell3.oidc_provider, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks_cell3.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller-sa"
            "${replace(module.eks_cell3.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# Attach the policy to the roles
resource "aws_iam_role_policy_attachment" "lb_controller_policy_attachment_cell1" {
  role       = aws_iam_role.lb_controller_role_cell1.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_iam_role_policy_attachment" "lb_controller_policy_attachment_cell2" {
  role       = aws_iam_role.lb_controller_role_cell2.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_iam_role_policy_attachment" "lb_controller_policy_attachment_cell3" {
  role       = aws_iam_role.lb_controller_role_cell3.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# IAM policy for AWS Load Balancer Controller
resource "aws_iam_policy" "lb_controller" {
  name        = "${local.name}-lb-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/policies/lb-controller-policy.json")
}

# Update EKS Blueprints Addons to include AWS Load Balancer Controller
locals {
  lb_controller_helm_config_cell1 = {
    set = [
      {
        name  = "clusterName"
        value = module.eks_cell1.cluster_name
      },
      {
        name  = "region"
        value = local.region
      },
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "serviceAccount.create"
        value = "true"
      },
      {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller-sa"
      },
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = aws_iam_role.lb_controller_role_cell1.arn
      },
      {
        name  = "ingressClassParams.name"
        value = "alb"
      },
      {
        name  = "ingressClassConfig.name"
        value = "alb"
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      },
      {
        name  = "enableCertManager"
        value = "false"
      },
      {
        name  = "nodeSelector.topology\\.kubernetes\\.io/zone"
        value = local.azs[0]
      },
      # Add chart version to ensure consistency across all cells
      {
        name  = "image.tag"
      #  value = "v2.7.1"
        value = "v2.9.2"
      },
      # Ensure controller is installed properly
      {
        name  = "replicaCount"
        value = "2"
      },
      #Allowing single subnet per ALB
      {
        name  = "featureGates.ALBSingleSubnet"
        value = "true"
      },
      #Disable cluster tag check
      {
        name  = "featureGates.SubnetsClusterTagCheck"
        value = "false"
      }
    ]
  }

  lb_controller_helm_config_cell2 = {
    set = [
      {
        name  = "clusterName"
        value = module.eks_cell2.cluster_name
      },
      {
        name  = "region"
        value = local.region
      },
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "serviceAccount.create"
        value = "true"
      },
      {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller-sa"
      },
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = aws_iam_role.lb_controller_role_cell2.arn
      },
      {
        name  = "ingressClassParams.name"
        value = "alb"
      },
      {
        name  = "ingressClassConfig.name"
        value = "alb"
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      },
      {
        name  = "enableCertManager"
        value = "false"
      },
      {
        name  = "nodeSelector.topology\\.kubernetes\\.io/zone"
        value = local.azs[1]
      },
      # Add chart version to ensure consistency across all cells
      {
        name  = "image.tag"
        value = "v2.9.2"
      },
      # Ensure controller is installed properly
      {
        name  = "replicaCount"
        value = "2"
      },
      #Allowing single subnet per ALB
      {
        name  = "featureGates.ALBSingleSubnet"
        value = "true"
      },
      #Disable cluster tag check
      {
        name  = "featureGates.SubnetsClusterTagCheck"
        value = "false"
      }
    ]
  }

  lb_controller_helm_config_cell3 = {
    set = [
      {
        name  = "clusterName"
        value = module.eks_cell3.cluster_name
      },
      {
        name  = "region"
        value = local.region
      },
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "serviceAccount.create"
        value = "true"
      },
      {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller-sa"
      },
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = aws_iam_role.lb_controller_role_cell3.arn
      },
      {
        name  = "ingressClassParams.name"
        value = "alb"
      },
      {
        name  = "ingressClassConfig.name"
        value = "alb"
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      },
      {
        name  = "enableCertManager"
        value = "false"
      },
      {
        name  = "nodeSelector.topology\\.kubernetes\\.io/zone"
        value = local.azs[2]
      },
      # Add chart version to ensure consistency across all cells
      {
        name  = "image.tag"
        value = "v2.9.2"
      },
      # Ensure controller is installed properly
      {
        name  = "replicaCount"
        value = "2"
      },
      #Allowing single subnet per ALB
      {
        name  = "featureGates.ALBSingleSubnet"
        value = "true"
      },
      #Disable cluster tag check
      {
        name  = "featureGates.SubnetsClusterTagCheck"
        value = "false"
      }
    ]
  }
}
