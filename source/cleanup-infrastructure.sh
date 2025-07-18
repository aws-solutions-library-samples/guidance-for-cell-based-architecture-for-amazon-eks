#!/bin/bash

# Script to clean up multi-cell Kubernetes and Terraform resources
# This script consolidates multiple cleanup steps into a single process with proper logging and error handling

# Set strict error handling
set -e

# Set the cell names similar to setup-env.sh
export CELL_1=eks-cell-az1
export CELL_2=eks-cell-az2
export CELL_3=eks-cell-az3
export AWS_REGION=us-west-2

# Get AWS account number
export AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query "Account" --output text)

# Color definitions for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for logging with timestamps
log() {
  local level=$1
  local message=$2
  local color=$3
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}${NC}"
}

info() {
  log "INFO" "$1" "${BLUE}"
}

success() {
  log "SUCCESS" "$1" "${GREEN}"
}

warn() {
  log "WARNING" "$1" "${YELLOW}"
}

error() {
  log "ERROR" "$1" "${RED}"
}

# Update kubeconfig for each cluster
update_kubeconfig() {
  info "=== UPDATING KUBECONFIG FOR EACH CLUSTER ==="
  
  execute "Updating kubeconfig for $CELL_1" \
    "aws eks update-kubeconfig --name $CELL_1 --region $AWS_REGION --alias $CELL_1"
  
  execute "Updating kubeconfig for $CELL_2" \
    "aws eks update-kubeconfig --name $CELL_2 --region $AWS_REGION --alias $CELL_2"
  
  execute "Updating kubeconfig for $CELL_3" \
    "aws eks update-kubeconfig --name $CELL_3 --region $AWS_REGION --alias $CELL_3"
  
  success "Kubeconfig updated for all clusters"
}

# Function to execute a command with logging
execute() {
  local description=$1
  local command=$2
  
  info "Starting: $description"
  echo -e "${YELLOW}Executing: $command${NC}"
  
  if eval "$command"; then
    success "Completed: $description"
    return 0
  else
    local exit_code=$?
    error "Failed: $description (Exit code: $exit_code)"
    return $exit_code
  fi
}

# Function to delete Kubernetes resources across cells
delete_k8s_resources() {
  info "=== DELETING KUBERNETES RESOURCES ==="
  
  local resource_types=("ingress" "service" "deployment")
  local cells=("cell1" "cell2" "cell3")
  
  for type in "${resource_types[@]}"; do
    info "Deleting $type resources across all cells"
    
    for i in {1..3}; do
      local cell="cell$i"
      local cell_var="CELL_$i"
      local context_var="${!cell_var}"
      
      if [ -z "$context_var" ]; then
        warn "Context variable $cell_var is not set, skipping $type deletion for $cell"
        continue
      fi
      
      local resource_name=""
      case "$type" in
        "ingress") resource_name="${cell}-ingress" ;;
        "service") resource_name="${cell}-service" ;;
        "deployment") resource_name="${cell}-app" ;;
      esac
      
      execute "Deleting $type/$resource_name from context $context_var" \
        "kubectl delete $type $resource_name --context $context_var --ignore-not-found=true || true"
    done
  done
  
  info "Waiting for Kubernetes resources to be deleted..."
  sleep 30
  success "Kubernetes resource deletion completed"
}

# Function to remove resources from Terraform state
remove_from_tf_state() {
  info "=== REMOVING RESOURCES FROM TERRAFORM STATE ==="
  
  local resource_types=("kubernetes_manifest" "kubernetes_service" "kubernetes_deployment")
  local resource_names=("cell1" "cell2" "cell3")
  local resource_suffixes=("_ingress" "_service" "_app")
  
  for i in "${!resource_types[@]}"; do
    local type="${resource_types[$i]}"
    local suffix="${resource_suffixes[$i]}"
    
    info "Removing $type resources from Terraform state"
    
    for cell in "${resource_names[@]}"; do
      local resource="${type}.${cell}${suffix}"
      execute "Removing $resource from Terraform state" \
        "terraform state rm $resource 2>/dev/null || true"
    done
  done
  
  success "Terraform state cleanup completed"
}

# Function to destroy Terraform resources in stages
destroy_terraform_resources() {
  info "=== DESTROYING TERRAFORM RESOURCES ==="
  
  # Stage 1: Route53 records
  info "Stage 1: Destroying Route53 records"
  execute "Destroying main Route53 records" \
    "terraform destroy -target=\"aws_route53_record.main\" -target=\"aws_route53_record.main_cell2\" -target=\"aws_route53_record.main_cell3\" -auto-approve"
  
  execute "Destroying alias Route53 records" \
    "terraform destroy -target=\"aws_route53_record.cell1_alias\" -target=\"aws_route53_record.cell2_alias\" -target=\"aws_route53_record.cell3_alias\" -auto-approve"
  
  # Stage 2: EKS addons
  info "Stage 2: Destroying EKS blueprint addons"
  for i in {1..3}; do
    execute "Destroying EKS blueprint addons for cell$i" \
      "terraform destroy -target=\"module.eks_blueprints_addons_cell$i\" -auto-approve"
  done
  
  # Stage 3: IAM roles and policies
  info "Stage 3: Destroying IAM roles and policies"
  execute "Destroying load balancer controller policy attachments" \
    "terraform destroy -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell1\" -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell2\" -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell3\" -auto-approve"
  
  execute "Destroying load balancer controller roles" \
    "terraform destroy -target=\"aws_iam_role.lb_controller_role_cell1\" -target=\"aws_iam_role.lb_controller_role_cell2\" -target=\"aws_iam_role.lb_controller_role_cell3\" -auto-approve"
  
  execute "Destroying load balancer controller policy" \
    "terraform destroy -target=\"aws_iam_policy.lb_controller\" -auto-approve"
  
  # Stage 4: EKS clusters
  info "Stage 4: Destroying EKS clusters"
  for i in {1..3}; do
    execute "Destroying EKS cluster cell$i" \
      "terraform destroy -target=\"module.eks_cell$i\" -auto-approve"
  done
  
  # Stage 5: Remaining resources
  info "Stage 5: Destroying remaining resources"
  execute "Destroying all remaining resources" \
    "terraform destroy -auto-approve"
  
  success "All Terraform resources have been destroyed"
}

# Main execution
main() {
  info "Starting cleanup process for multi-cell infrastructure"
  
  # Check if required environment variables are set
  for i in {1..3}; do
    local cell_var="CELL_$i"
    if [ -z "${!cell_var}" ]; then
      warn "$cell_var environment variable is not set. Some operations may fail."
    else
      info "$cell_var is set to ${!cell_var}"
    fi
  done
  
  # Update kubeconfig for all clusters
  update_kubeconfig
  
  # Execute each stage with error handling
  if delete_k8s_resources; then
    info "Kubernetes resource deletion completed successfully"
  else
    warn "Some Kubernetes resources may not have been deleted properly, continuing with next steps"
  fi
  
  if remove_from_tf_state; then
    info "Terraform state cleanup completed successfully"
  else
    warn "Some Terraform state operations may have failed, continuing with next steps"
  fi
  
  if destroy_terraform_resources; then
    success "Terraform resource destruction completed successfully"
  else
    error "Terraform resource destruction encountered errors"
    exit 1
  fi
  
  success "===== CLEANUP PROCESS COMPLETED SUCCESSFULLY ====="
}

# Execute the main function
main
