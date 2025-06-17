################################################################################
# Target Registration Configuration
################################################################################

# This file contains the configuration for registering targets with the ALBs
# In a real implementation, you would use AWS Load Balancer Controller with
# proper node selectors or affinity rules to ensure traffic isolation

# Note: These resources are commented out as they are placeholders
# In a real implementation, you would use one of these approaches:

# 1. AWS Load Balancer Controller with ingress resources
# 2. Kubernetes service annotations
# 3. Direct registration of instances using data sources

/*
# Example of how to get the instance IDs for Cell 1 (AZ1)
data "aws_instances" "cell1_instances" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [local.cell1_name]
  }
  
  filter {
    name   = "availability-zone"
    values = [local.azs[0]]
  }
}

# Example of registering Cell 1 instances to Cell 1 target group
resource "aws_lb_target_group_attachment" "cell1_attachment" {
  count            = length(data.aws_instances.cell1_instances.ids)
  target_group_arn = aws_lb_target_group.cell1_tg.arn
  target_id        = data.aws_instances.cell1_instances.ids[count.index]
  port             = 443
}
*/

# In practice, you would use AWS Load Balancer Controller with Kubernetes manifests like:

/*
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cell1-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/load-balancer-name: ${local.cell1_name}-alb
    alb.ingress.kubernetes.io/subnets: ${module.vpc.public_subnets[0]}
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: ${var.acm_certificate_arn}
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTPS
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/node-selector: topology.kubernetes.io/zone=${local.azs[0]}
spec:
  rules:
  - host: cell1.${var.domain_name}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cell1-service
            port:
              number: 443
*/