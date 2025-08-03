#!/bin/bash

# Script to clean up multi-cell Kubernetes and Terraform resources
# This script consolidates multiple cleanup steps into a single process with proper logging and error handling
# Updated to work with actual deployment values from terraform.tfvars

# Set strict error handling
set -e

# Extract values from terraform.tfvars to match actual deployment
DOMAIN_NAME=$(awk -F'=' '/^domain_name/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "")
AWS_REGION=$(awk -F'=' '/^region/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "us-west-2")

# Set the cell names based on actual deployment pattern
export CELL_1=eks-cell-az1
export CELL_2=eks-cell-az2
export CELL_3=eks-cell-az3
export AWS_REGION=${AWS_REGION}

# Get AWS account number
export AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "")

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

# Function to check prerequisites
check_prerequisites() {
  info "=== CHECKING PREREQUISITES ==="
  
  # Check if terraform.tfvars exists
  if [ ! -f "terraform.tfvars" ]; then
    error "terraform.tfvars file not found. Please run this script from the directory containing terraform.tfvars"
    exit 1
  fi
  
  # Display extracted values
  info "Extracted configuration:"
  info "  Domain Name: ${DOMAIN_NAME:-'Not found'}"
  info "  AWS Region: ${AWS_REGION}"
  info "  AWS Account: ${AWS_ACCOUNT_NUMBER:-'Not found'}"
  
  # Check AWS CLI configuration
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error "AWS CLI not properly configured. Please configure AWS credentials."
    exit 1
  fi
  
  # Check if kubectl is available
  if ! command -v kubectl >/dev/null 2>&1; then
    warn "kubectl not found. Kubernetes resource cleanup will be skipped."
    return 1
  fi
  
  # Check if terraform is available
  if ! command -v terraform >/dev/null 2>&1; then
    error "terraform not found. Please install Terraform."
    exit 1
  fi
  
  success "Prerequisites check completed"
  return 0
}

# Update kubeconfig for each cluster
update_kubeconfig() {
  info "=== UPDATING KUBECONFIG FOR EACH CLUSTER ==="
  
  # Check if clusters exist before updating kubeconfig
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    if aws eks describe-cluster --name "$cell_name" --region "$AWS_REGION" >/dev/null 2>&1; then
      execute "Updating kubeconfig for $cell_name" \
        "aws eks update-kubeconfig --name $cell_name --region $AWS_REGION --alias $cell_name"
    else
      warn "EKS cluster $cell_name not found or not accessible, skipping kubeconfig update"
    fi
  done
  
  success "Kubeconfig update completed"
}

# Function to delete Kubernetes resources across cells
delete_k8s_resources() {
  info "=== DELETING KUBERNETES RESOURCES ==="
  
  # Check if kubectl is available
  if ! command -v kubectl >/dev/null 2>&1; then
    warn "kubectl not available, skipping Kubernetes resource cleanup"
    return 0
  fi
  
  local resource_types=("ingress" "service" "deployment")
  
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
      
      # Check if context exists
      if ! kubectl config get-contexts "$context_var" >/dev/null 2>&1; then
        warn "Kubectl context $context_var not found, skipping $type deletion for $cell"
        continue
      fi
      
      local resource_name=""
      case "$type" in
        "ingress") resource_name="${cell}-ingress" ;;
        "service") resource_name="${cell}-service" ;;
        "deployment") resource_name="${cell}-app" ;;
      esac
      
      execute "Deleting $type/$resource_name from context $context_var" \
        "kubectl delete $type $resource_name --context $context_var --ignore-not-found=true --timeout=60s || true"
    done
  done
  
  info "Waiting for Kubernetes resources to be deleted..."
  sleep 30
  success "Kubernetes resource deletion completed"
}

# Function to remove resources from Terraform state
remove_from_tf_state() {
  info "=== REMOVING RESOURCES FROM TERRAFORM STATE ==="
  
  # Check if terraform state exists
  if [ ! -f "terraform.tfstate" ]; then
    warn "terraform.tfstate not found, skipping state cleanup"
    return 0
  fi
  
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

# Function to handle CloudWatch Logs cleanup
handle_cloudwatch_logs() {
  info "=== HANDLING CLOUDWATCH LOGS CLEANUP ==="
  
  # Try to manually delete CloudWatch Log Groups if they exist
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    if [ -n "$cell_name" ]; then
      local log_group_name="/aws/eks/${cell_name}/cluster"
      
      info "Checking if CloudWatch Log Group $log_group_name exists"
      if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --region "$AWS_REGION" 2>/dev/null | grep -q "$log_group_name"; then
        execute "Manually deleting CloudWatch Log Group $log_group_name" \
          "aws logs delete-log-group --log-group-name \"$log_group_name\" --region \"$AWS_REGION\" || true"
      else
        info "CloudWatch Log Group $log_group_name does not exist or cannot be accessed"
      fi
    fi
  done
  
  # Remove CloudWatch Log Groups from Terraform state
  for i in {1..3}; do
    execute "Removing CloudWatch Log Group for cell$i from Terraform state" \
      "terraform state rm module.eks_cell$i.aws_cloudwatch_log_group.this[0] 2>/dev/null || true"
  done
  
  success "CloudWatch Logs cleanup completed"
}

# Function to destroy Terraform resources in stages
destroy_terraform_resources() {
  info "=== DESTROYING TERRAFORM RESOURCES ==="
  
  # Initialize terraform if needed
  if [ ! -d ".terraform" ]; then
    execute "Initializing Terraform" \
      "terraform init"
  fi
  
  # Handle CloudWatch Logs resources with special error handling
  info "Pre-stage: Handling CloudWatch Logs resources"
  handle_cloudwatch_logs
  
  # Stage 1: Kubernetes resources (if they exist in terraform state)
  info "Stage 1: Destroying Kubernetes resources"
  local k8s_resources=("kubernetes_manifest.cell1_ingress" "kubernetes_manifest.cell2_ingress" "kubernetes_manifest.cell3_ingress"
                       "kubernetes_service.cell1_service" "kubernetes_service.cell2_service" "kubernetes_service.cell3_service"
                       "kubernetes_deployment.cell1_app" "kubernetes_deployment.cell2_app" "kubernetes_deployment.cell3_app")
  
  for resource in "${k8s_resources[@]}"; do
    execute "Destroying $resource" \
      "terraform destroy -target=\"$resource\" -auto-approve || true"
  done
  
  # Stage 2: Route53 records
  info "Stage 2: Destroying Route53 records"
  execute "Destroying Route53 records" \
    "terraform destroy -target=\"aws_route53_record.main\" -target=\"aws_route53_record.main_cell2\" -target=\"aws_route53_record.main_cell3\" -auto-approve || true"
  
  execute "Destroying alias Route53 records" \
    "terraform destroy -target=\"aws_route53_record.cell1_alias\" -target=\"aws_route53_record.cell2_alias\" -target=\"aws_route53_record.cell3_alias\" -auto-approve || true"
  
  # Stage 3: EKS addons
  info "Stage 3: Destroying EKS blueprint addons"
  for i in {1..3}; do
    execute "Destroying EKS blueprint addons for cell$i" \
      "terraform destroy -target=\"module.eks_blueprints_addons_cell$i\" -auto-approve || true"
  done
  
  # Stage 4: Load Balancer Controller resources
  info "Stage 4: Destroying Load Balancer Controller resources"
  execute "Destroying load balancer controller policy attachments" \
    "terraform destroy -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell1\" -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell2\" -target=\"aws_iam_role_policy_attachment.lb_controller_policy_attachment_cell3\" -auto-approve || true"
  
  execute "Destroying load balancer controller roles" \
    "terraform destroy -target=\"aws_iam_role.lb_controller_role_cell1\" -target=\"aws_iam_role.lb_controller_role_cell2\" -target=\"aws_iam_role.lb_controller_role_cell3\" -auto-approve || true"
  
  execute "Destroying load balancer controller policy" \
    "terraform destroy -target=\"aws_iam_policy.lb_controller\" -auto-approve || true"
  
  # Stage 5: EKS clusters
  info "Stage 5: Destroying EKS clusters"
  for i in {1..3}; do
    execute "Destroying EKS cluster cell$i" \
      "terraform destroy -target=\"module.eks_cell$i\" -auto-approve || warn \"Failed to destroy EKS cluster cell$i, continuing with next steps\""
  done
  
  # Stage 6: VPC and remaining resources
  info "Stage 6: Destroying VPC and remaining resources"
  execute "Destroying all remaining resources" \
    "terraform destroy -auto-approve"
  
  success "All Terraform resources have been destroyed"
}

# Function to clean up local files
cleanup_local_files() {
  info "=== CLEANING UP LOCAL FILES ==="
  
  # Remove terraform state files
  execute "Removing terraform state files" \
    "rm -f terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl || true"
  
  # Remove terraform directory
  execute "Removing .terraform directory" \
    "rm -rf .terraform || true"
  
  # Clean up kubectl contexts
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    if [ -n "$cell_name" ]; then
      execute "Removing kubectl context for $cell_name" \
        "kubectl config delete-context $cell_name 2>/dev/null || true"
    fi
  done
  
  success "Local file cleanup completed"
}

# Function to verify cleanup
verify_cleanup() {
  info "=== VERIFYING CLEANUP ==="
  
  # Check if EKS clusters still exist
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    if aws eks describe-cluster --name "$cell_name" --region "$AWS_REGION" >/dev/null 2>&1; then
      warn "EKS cluster $cell_name still exists"
    else
      success "EKS cluster $cell_name successfully deleted"
    fi
  done
  
  # Check if Route53 records still exist (if domain name was found)
  if [ -n "$DOMAIN_NAME" ]; then
    local hosted_zone_id=$(awk -F'=' '/^route53_zone_id/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "")
    
    if [ -n "$hosted_zone_id" ]; then
      info "Checking Route53 records for cleanup verification"
      local remaining_records=$(aws route53 list-resource-record-sets --hosted-zone-id "$hosted_zone_id" --query "ResourceRecordSets[?contains(Name,'$DOMAIN_NAME') && Type=='A']" --output text 2>/dev/null | wc -l)
      
      if [ "$remaining_records" -gt 0 ]; then
        warn "$remaining_records Route53 A records still exist for $DOMAIN_NAME"
      else
        success "All Route53 A records for $DOMAIN_NAME have been cleaned up"
      fi
    fi
  fi
  
  success "Cleanup verification completed"
}

# Main execution
main() {
  info "Starting cleanup process for multi-cell infrastructure"
  info "Detected configuration: Domain=$DOMAIN_NAME, Region=$AWS_REGION"
  
  # Check prerequisites
  if ! check_prerequisites; then
    error "Prerequisites check failed"
    exit 1
  fi
  
  # Confirmation prompt
  echo ""
  warn "This will destroy ALL resources created by this Terraform configuration."
  warn "This action is IRREVERSIBLE."
  echo ""
  read -p "Are you sure you want to continue? (yes/no): " -r
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cleanup cancelled by user"
    exit 0
  fi
  
  # Update kubeconfig for all clusters
  update_kubeconfig || warn "Some kubeconfig updates failed, continuing with cleanup"
  
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
    error "Terraform resource destruction encountered errors, but continuing with local cleanup"
  fi
  
  # Clean up local files
  cleanup_local_files
  
  # Verify cleanup
  verify_cleanup
  
  success "===== CLEANUP PROCESS COMPLETED ====="
  info "Please verify in the AWS Console that all resources have been properly deleted."
  info "Check the following services: EKS, EC2, VPC, Route53, IAM, CloudWatch Logs"
}

# Execute the main function
main "$@"
