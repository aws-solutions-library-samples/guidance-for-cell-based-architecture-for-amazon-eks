################################################################################
# Kubernetes Manifests for ALB Ingress
################################################################################


# Example service for Cell 1
resource "kubernetes_service" "cell1_service" {
  provider = kubernetes.k8s-cell1
  
  metadata {
    name      = "cell1-service"
    namespace = "default"
  }
  
  spec {
    selector = {
      app = "cell1-app"
    }
    
    port {
      port        = 80
      target_port = 80
    }
    
    type = "NodePort"
  }
}

# Example service for Cell 2
resource "kubernetes_service" "cell2_service" {
  provider = kubernetes.k8s-cell2
  
  metadata {
    name      = "cell2-service"
    namespace = "default"
  }
  
  spec {
    selector = {
      app = "cell2-app"
    }
    
    port {
      port        = 80
      target_port = 80
    }
    
    type = "NodePort"
  }
}

# Example service for Cell 3
resource "kubernetes_service" "cell3_service" {
  provider = kubernetes.k8s-cell3
  
  metadata {
    name      = "cell3-service"
    namespace = "default"
  }
  
  spec {
    selector = {
      app = "cell3-app"
    }
    
    port {
      port        = 80
      target_port = 80
    }
    
    type = "NodePort"
  }
}

# Create a dummy deployment for cell1 to ensure there's a target for the ALB
resource "kubernetes_deployment" "cell1_app" {
  provider = kubernetes.k8s-cell1
  
  metadata {
    name      = "cell1-app"
    namespace = "default"
  }
  
  spec {
    replicas = 2
    
    selector {
      match_labels = {
        app = "cell1-app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "cell1-app"
        }
      }
      
      spec {
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "karpenter.sh/nodepool"
                  operator = "Exists"
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 90
              preference {
                match_expressions {
                  key      = "node-type"
                  operator = "In"
                  values   = ["karpenter"]
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 80
              preference {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "DoesNotExist"
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "topology.kubernetes.io/zone"
                  operator = "In"
                  values   = [local.azs[0]]
                }
              }
            }
          }
        }
        
        container {
          name  = "nginx"
          image = "nginx:latest"
          
          port {
            container_port = 80
          }
          
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "0.2"
              memory = "256Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

# Create a dummy deployment for cell2 to ensure there's a target for the ALB
resource "kubernetes_deployment" "cell2_app" {
  provider = kubernetes.k8s-cell2
  
  metadata {
    name      = "cell2-app"
    namespace = "default"
  }
  
  spec {
    replicas = 2
    
    selector {
      match_labels = {
        app = "cell2-app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "cell2-app"
        }
      }
      
      spec {
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "karpenter.sh/nodepool"
                  operator = "Exists"
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 90
              preference {
                match_expressions {
                  key      = "node-type"
                  operator = "In"
                  values   = ["karpenter"]
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 80
              preference {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "DoesNotExist"
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "topology.kubernetes.io/zone"
                  operator = "In"
                  values   = [local.azs[1]]
                }
              }
            }
          }
        }
        
        container {
          name  = "nginx"
          image = "nginx:latest"
          
          port {
            container_port = 80
          }
          
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "0.2"
              memory = "256Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

# Create a dummy deployment for cell3 to ensure there's a target for the ALB
resource "kubernetes_deployment" "cell3_app" {
  provider = kubernetes.k8s-cell3
  
  metadata {
    name      = "cell3-app"
    namespace = "default"
  }
  
  spec {
    replicas = 2
    
    selector {
      match_labels = {
        app = "cell3-app"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "cell3-app"
        }
      }
      
      spec {
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "karpenter.sh/nodepool"
                  operator = "Exists"
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 90
              preference {
                match_expressions {
                  key      = "node-type"
                  operator = "In"
                  values   = ["karpenter"]
                }
              }
            }
            preferred_during_scheduling_ignored_during_execution {
              weight = 80
              preference {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "DoesNotExist"
                }
              }
            }
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "topology.kubernetes.io/zone"
                  operator = "In"
                  values   = [local.azs[2]]
                }
              }
            }
          }
        }
        
        container {
          name  = "nginx"
          image = "nginx:latest"
          
          port {
            container_port = 80
          }
          
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "0.2"
              memory = "256Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

# Kubernetes manifests for Cell 1 Ingress
resource "kubernetes_manifest" "cell1_ingress" {
  provider = kubernetes.k8s-cell1
  
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "cell1-ingress"
      namespace = "default"
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        "alb.ingress.kubernetes.io/target-group-attributes" = "load_balancing.cross_zone.enabled=false"
        #"alb.ingress.kubernetes.io/target-group-attributes" = join(",", [ "stickiness.enabled=true", "stickiness.lb_cookie.duration_seconds=86400", "load_balancing.cross_zone.enabled=false"])
        "alb.ingress.kubernetes.io/tags"                 = "cell=cell1,az=${local.azs[0]}"
        "alb.ingress.kubernetes.io/load-balancer-name"   = "${local.cell1_name}-alb"
        "alb.ingress.kubernetes.io/subnets"              = join(",", module.vpc.public_subnets)
        #"alb.ingress.kubernetes.io/subnets" = join(",", [ module.vpc.public_subnets[index(local.azs, local.azs[0])], module.vpc.public_subnets[index(local.azs, local.azs[0])] ])
        "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/certificate-arn"      = var.acm_certificate_arn
        "alb.ingress.kubernetes.io/ssl-policy"           = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-path"     = "/"
        "alb.ingress.kubernetes.io/node-selector"        = "topology.kubernetes.io/zone=${local.azs[0]}"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
      }
    }
    spec = {
      rules = [
        {
          host = "cell1.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "cell1-service"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell1,
    kubernetes_deployment.cell1_app,
    kubernetes_service.cell1_service
  ]
}

# Disable cross zone load balancing
resource "null_resource" "cell1_tg_config" {
  depends_on = [kubernetes_manifest.cell1_ingress]

  provisioner "local-exec" {
    command = <<EOT
      ALB_NAME="${local.cell1_name}-alb"
      TG_ARN=$(aws elbv2 describe-target-groups \
        --query "TargetGroups[?starts_with(TargetGroupName, '$ALB_NAME')].TargetGroupArn" \
        --output text)

      aws elbv2 modify-target-group-attributes \
        --target-group-arn $TG_ARN \
        --attributes Key=load_balancing.cross_zone.enabled,Value=false
    EOT
  }
}

# Kubernetes manifests for Cell 2 Ingress
resource "kubernetes_manifest" "cell2_ingress" {
  provider = kubernetes.k8s-cell2
  
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "cell2-ingress"
      namespace = "default"
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        "alb.ingress.kubernetes.io/target-group-attributes" = "load_balancing.cross_zone.enabled=false"
        #"alb.ingress.kubernetes.io/target-group-attributes" = join(",", [ "stickiness.enabled=true", "stickiness.lb_cookie.duration_seconds=86400", "load_balancing.cross_zone.enabled=false"])
        "alb.ingress.kubernetes.io/tags"                 = "cell=cell2,az=${local.azs[1]}"
        "alb.ingress.kubernetes.io/load-balancer-name"   = "${local.cell2_name}-alb"
        "alb.ingress.kubernetes.io/subnets"              = join(",", module.vpc.public_subnets)
        #"alb.ingress.kubernetes.io/subnets" = join(",", [ module.vpc.public_subnets[index(local.azs, local.azs[1])], module.vpc.public_subnets[index(local.azs, local.azs[1])] ]) 
        "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/certificate-arn"      = var.acm_certificate_arn
        "alb.ingress.kubernetes.io/ssl-policy"           = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-path"     = "/"
        "alb.ingress.kubernetes.io/node-selector"        = "topology.kubernetes.io/zone=${local.azs[1]}"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
        #"alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true,load_balancing.cross_zone.enabled=false"
      }
    }
    spec = {
      rules = [
        {
          host = "cell2.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "cell2-service"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell2,
    kubernetes_deployment.cell2_app,
    kubernetes_service.cell2_service
  ]
}


# Disable cross zone load balancing
resource "null_resource" "cell2_tg_config" {
  depends_on = [kubernetes_manifest.cell2_ingress]

  provisioner "local-exec" {
    command = <<EOT
      ALB_NAME="${local.cell2_name}-alb"
      TG_ARN=$(aws elbv2 describe-target-groups \
        --query "TargetGroups[?starts_with(TargetGroupName, '$ALB_NAME')].TargetGroupArn" \
        --output text)

      aws elbv2 modify-target-group-attributes \
        --target-group-arn $TG_ARN \
        --attributes Key=load_balancing.cross_zone.enabled,Value=false
    EOT
  }
}

# Kubernetes manifests for Cell 3 Ingress
resource "kubernetes_manifest" "cell3_ingress" {
  provider = kubernetes.k8s-cell3
  
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "cell3-ingress"
      namespace = "default"
      annotations = {
        "kubernetes.io/ingress.class"                    = "alb"
        "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
        "alb.ingress.kubernetes.io/target-type"          = "ip"
        #"alb.ingress.kubernetes.io/target-group-attributes" = join(",", [ "stickiness.enabled=true", "stickiness.lb_cookie.duration_seconds=86400", "load_balancing.cross_zone.enabled=false"])
        "alb.ingress.kubernetes.io/target-group-attributes" = "load_balancing.cross_zone.enabled=false"
        "alb.ingress.kubernetes.io/tags"                 = "cell=cell3,az=${local.azs[2]}"
        "alb.ingress.kubernetes.io/load-balancer-name"   = "${local.cell3_name}-alb"
        "alb.ingress.kubernetes.io/subnets"              = join(",", module.vpc.public_subnets)
        #"alb.ingress.kubernetes.io/subnets" = join(",", [ module.vpc.public_subnets[index(local.azs, local.azs[2])], module.vpc.public_subnets[index(local.azs, local.azs[2])] ])
        "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\":80},{\"HTTPS\":443}]"
        "alb.ingress.kubernetes.io/certificate-arn"      = var.acm_certificate_arn
        "alb.ingress.kubernetes.io/ssl-policy"           = "ELBSecurityPolicy-TLS13-1-2-2021-06"
        "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
        "alb.ingress.kubernetes.io/healthcheck-path"     = "/"
        "alb.ingress.kubernetes.io/node-selector"        = "topology.kubernetes.io/zone=${local.azs[2]}"
        "alb.ingress.kubernetes.io/actions.ssl-redirect" = "{\"Type\":\"redirect\",\"RedirectConfig\":{\"Protocol\":\"HTTPS\",\"Port\":\"443\",\"StatusCode\":\"HTTP_301\"}}"
        #"alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true,load_balancing.cross_zone.enabled=false"
      }
    }
    spec = {
      rules = [
        {
          host = "cell3.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "cell3-service"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell3,
    kubernetes_deployment.cell3_app,
    kubernetes_service.cell3_service
  ]
}

# Disable cross zone load balancing
resource "null_resource" "cell3_tg_config" {
  depends_on = [kubernetes_manifest.cell3_ingress]

  provisioner "local-exec" {
    command = <<EOT
      ALB_NAME="${local.cell3_name}-alb"
      TG_ARN=$(aws elbv2 describe-target-groups \
        --query "TargetGroups[?starts_with(TargetGroupName, '$ALB_NAME')].TargetGroupArn" \
        --output text)

      aws elbv2 modify-target-group-attributes \
        --target-group-arn $TG_ARN \
        --attributes Key=load_balancing.cross_zone.enabled,Value=false
    EOT
  }
}

################################################################################
# Karpenter NodePool and EC2NodeClass Resources
################################################################################

# Karpenter EC2NodeClass for Cell 1
resource "kubernetes_manifest" "karpenter_ec2nodeclass_cell1" {
  provider = kubernetes.k8s-cell1
  
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-x86_64-standard-*"
        },
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-arm64-standard-*"
        },
        {
          owner = "amazon"
          tags = {
            "Name" = "amazon-eks-node-al2023-*"
          }
        }
      ]
      role      = module.eks_blueprints_addons_cell1.karpenter.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell1_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell1_name
          }
        }
      ]
      tags = {
        "karpenter.sh/discovery" = local.cell1_name
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell1
  ]
}

# Karpenter NodePool for Cell 1
resource "kubernetes_manifest" "karpenter_nodepool_cell1" {
  provider = kubernetes.k8s-cell1
  
  manifest = {
    apiVersion = "karpenter.sh/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            node-type = "karpenter"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = ["4", "8", "16", "32"]
            },
            {
              key      = "karpenter.k8s.aws/instance-hypervisor"
              operator = "In"
              values   = ["nitro"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = [local.azs[0]]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            }
          ]
        }
      }
      limits = {
        cpu = 10000
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2nodeclass_cell1
  ]
}

# Karpenter EC2NodeClass for Cell 2
resource "kubernetes_manifest" "karpenter_ec2nodeclass_cell2" {
  provider = kubernetes.k8s-cell2
  
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-x86_64-standard-*"
        },
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-arm64-standard-*"
        },
        {
          owner = "amazon"
          tags = {
            "Name" = "amazon-eks-node-al2023-*"
          }
        }
      ]
      role      = module.eks_blueprints_addons_cell2.karpenter.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell2_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell2_name
          }
        }
      ]
      tags = {
        "karpenter.sh/discovery" = local.cell2_name
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell2
  ]
}

# Karpenter NodePool for Cell 2
resource "kubernetes_manifest" "karpenter_nodepool_cell2" {
  provider = kubernetes.k8s-cell2
  
  manifest = {
    apiVersion = "karpenter.sh/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            node-type = "karpenter"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = ["4", "8", "16", "32"]
            },
            {
              key      = "karpenter.k8s.aws/instance-hypervisor"
              operator = "In"
              values   = ["nitro"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = [local.azs[1]]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            }
          ]
        }
      }
      limits = {
        cpu = 10000
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2nodeclass_cell2
  ]
}

# Karpenter EC2NodeClass for Cell 3
resource "kubernetes_manifest" "karpenter_ec2nodeclass_cell3" {
  provider = kubernetes.k8s-cell3
  
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-x86_64-standard-*"
        },
        {
          owner = "amazon"
          name  = "amazon-eks-node-al2023-arm64-standard-*"
        },
        {
          owner = "amazon"
          tags = {
            "Name" = "amazon-eks-node-al2023-*"
          }
        }
      ]
      role      = module.eks_blueprints_addons_cell3.karpenter.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell3_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cell3_name
          }
        }
      ]
      tags = {
        "karpenter.sh/discovery" = local.cell3_name
      }
    }
  }

  depends_on = [
    module.eks_blueprints_addons_cell3
  ]
}

# Karpenter NodePool for Cell 3
resource "kubernetes_manifest" "karpenter_nodepool_cell3" {
  provider = kubernetes.k8s-cell3
  
  manifest = {
    apiVersion = "karpenter.sh/v1"  # Updated to v1 for Karpenter v1.0.5+
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            node-type = "karpenter"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = ["4", "8", "16", "32"]
            },
            {
              key      = "karpenter.k8s.aws/instance-hypervisor"
              operator = "In"
              values   = ["nitro"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = [local.azs[2]]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            }
          ]
        }
      }
      limits = {
        cpu = 10000
      }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [
    kubernetes_manifest.karpenter_ec2nodeclass_cell3
  ]
}
