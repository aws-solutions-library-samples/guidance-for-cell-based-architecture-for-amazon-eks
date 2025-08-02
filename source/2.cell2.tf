provider "kubernetes" {
  alias                  = "k8s-cell2"
  host                   = module.eks_cell2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cell2.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks_cell2.cluster_name]
  }
}

provider "helm" {
  alias = "helm-cell2"
  kubernetes  {
    host                   = module.eks_cell2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cell2.cluster_certificate_authority_data)

    exec  {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks_cell2.cluster_name]
    }
  }
}

################################################################################
# Cluster
################################################################################

module "eks_cell2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  providers = {
    kubernetes = kubernetes.k8s-cell2
  }

  cluster_name                   = local.cell2_name
  cluster_version                = "1.31"
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    cell2 = {
      instance_types = ["m5.large"]

      min_size     = 1
      max_size     = 5
      desired_size = 2

      subnet_ids = [module.vpc.private_subnets[1]]
    }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.cell2_name
  })
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "eks_blueprints_addons_cell2" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.22"  # Latest version supporting Karpenter v1.x with EKS 1.31

  providers = {
    helm       = helm.helm-cell2
    kubernetes = kubernetes.k8s-cell2
  }

  cluster_name      = module.eks_cell2.cluster_name
  cluster_endpoint  = module.eks_cell2.cluster_endpoint
  cluster_version   = module.eks_cell2.cluster_version
  oidc_provider_arn = module.eks_cell2.oidc_provider_arn

  # We want to wait for the EKS Managed Nodegroups to be deployed first
  create_delay_dependencies = [for group in module.eks_cell2.eks_managed_node_groups : group.node_group_arn]

  eks_addons = {
    coredns    = {}
    vpc-cni    = {}
    kube-proxy = {}
  }

  enable_karpenter = true
  karpenter = {
    # Use Karpenter v1.0.5+ which officially supports Kubernetes 1.31
    chart_version = "1.0.5"
    repository_url = "oci://public.ecr.aws/karpenter/karpenter"
    # Additional v1.x specific configurations
    set = [
      {
        name  = "settings.clusterName"
        value = module.eks_cell2.cluster_name
      },
      {
        name  = "settings.clusterEndpoint"
        value = module.eks_cell2.cluster_endpoint
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "1"
      },
      {
        name  = "controller.resources.requests.memory"
        value = "1Gi"
      }
    ]
  }
  karpenter_node = {
    # Use static name so that it matches what is defined in `az2.yaml` example manifest
    iam_role_use_name_prefix = false
  }

  # AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = local.lb_controller_helm_config_cell2.set
    # Specify chart version for consistency
    chart_version = "1.7.1"
  }

  tags = local.tags
}

resource "aws_eks_access_entry" "karpenter_node_access_entry_cell2" {
  cluster_name      = module.eks_cell2.cluster_name
  principal_arn     = module.eks_blueprints_addons_cell2.karpenter.node_iam_role_arn
  type              = "EC2_LINUX"
  
  lifecycle {
    ignore_changes = [
      user_name
    ]
  }
}