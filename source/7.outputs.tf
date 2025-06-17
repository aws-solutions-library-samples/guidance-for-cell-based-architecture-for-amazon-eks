################################################################################
# Outputs
################################################################################

output "route53_zone_id" {
  description = "ID of the Route53 zone"
  value       = var.route53_zone_id
}

output "domain_name" {
  description = "Domain name for the cellular architecture"
  value       = var.domain_name
}

output "cell1_cluster_name" {
  description = "Name of Cell 1 EKS cluster"
  value       = module.eks_cell1.cluster_name
}

output "cell2_cluster_name" {
  description = "Name of Cell 2 EKS cluster"
  value       = module.eks_cell2.cluster_name
}

output "cell3_cluster_name" {
  description = "Name of Cell 3 EKS cluster"
  value       = module.eks_cell3.cluster_name
}

output "subnet_id_az1" {
  description = "Subnet ID for AZ1"
  value       = module.vpc.private_subnets[0]
}

output "subnet_id_az2" {
  description = "Subnet ID for AZ2"
  value       = module.vpc.private_subnets[1]
}

output "subnet_id_az3" {
  description = "Subnet ID for AZ3"
  value       = module.vpc.private_subnets[2]
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = var.acm_certificate_arn
}

output "cell1_ingress_host" {
  description = "Hostname for Cell 1 ingress"
  value       = "cell1.${var.domain_name}"
}

output "cell2_ingress_host" {
  description = "Hostname for Cell 2 ingress"
  value       = "cell2.${var.domain_name}"
}

output "cell3_ingress_host" {
  description = "Hostname for Cell 3 ingress"
  value       = "cell3.${var.domain_name}"
}

output "cell1_tg_attributes" {
  value = null_resource.cell1_tg_config.id
}

output "cell2_tg_attributes" {
  value = null_resource.cell2_tg_config.id
}

output "cell3_tg_attributes" {
  value = null_resource.cell3_tg_config.id
}



# Setup Script Output
output "setup_script" {
  description = "Script to set up environment variables"
  value       = <<-EOT
#!/bin/bash

# Set the cell names
export CELL_1=${local.cell1_name}
export CELL_2=${local.cell2_name}
export CELL_3=${local.cell3_name}
export AWS_REGION=${local.region}

# Get AWS account number
export AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query "Account" --output text)

# Get subnet IDs
export SUBNET_ID_CELL1=$(terraform output -raw subnet_id_az1)
export SUBNET_ID_CELL2=$(terraform output -raw subnet_id_az2)
export SUBNET_ID_CELL3=$(terraform output -raw subnet_id_az3)

# Set up kubectl alias
alias kgn="kubectl get node -o custom-columns='NODE_NAME:.metadata.name,READY:.status.conditions[?(@.type==\"Ready\")].status,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,AZ:.metadata.labels.topology\.kubernetes\.io/zone,CAPACITY-TYPE:.metadata.labels.karpenter\.sh/capacity-type,VERSION:.status.nodeInfo.kubeletVersion,OS-IMAGE:.status.nodeInfo.osImage,INTERNAL-IP:.metadata.annotations.alpha\.kubernetes\.io/provided-node-ip'"

# Update kubeconfig for each cluster
aws eks update-kubeconfig --name $CELL_1 --region $AWS_REGION --alias $CELL_1
aws eks update-kubeconfig --name $CELL_2 --region $AWS_REGION --alias $CELL_2
aws eks update-kubeconfig --name $CELL_3 --region $AWS_REGION --alias $CELL_3

echo "Environment setup complete!"
echo "You can now use the following commands to interact with the clusters:"
echo "kubectl get nodes --context \$CELL_1"
echo "kubectl get nodes --context \$CELL_2"
echo "kubectl get nodes --context \$CELL_3"
echo "Or use the kgn alias for more detailed node information:"
echo "kgn --context \$CELL_1"
EOT
}

# Restart Script Output
output "restart_lb_controller_script" {
  description = "Script to restart AWS Load Balancer Controller pods"
  value       = <<-EOT
#!/bin/bash

# Source the setup script first if environment variables are not set
if [ -z "$CELL_1" ] || [ -z "$CELL_2" ] || [ -z "$CELL_3" ] || [ -z "$AWS_REGION" ]; then
  echo "Environment variables not set. Please run 'source setup-env.sh' first or set them manually."
  exit 1
fi

# Restart AWS Load Balancer Controller pods
echo "Restarting AWS Load Balancer Controller pods..."
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_1
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_2
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_3

echo "AWS Load Balancer Controller pods restarted!"
EOT
}
