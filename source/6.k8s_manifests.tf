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
        node_selector = {
          "topology.kubernetes.io/zone" = local.azs[0]
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
        node_selector = {
          "topology.kubernetes.io/zone" = local.azs[1]
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
        node_selector = {
          "topology.kubernetes.io/zone" = local.azs[2]
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
