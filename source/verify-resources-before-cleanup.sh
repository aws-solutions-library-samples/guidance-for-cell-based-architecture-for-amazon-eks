#!/bin/bash

# Script to verify what resources exist before cleanup
# This helps understand what will be deleted and identify any issues

# Set strict error handling
set -e

# Extract values from terraform.tfvars
DOMAIN_NAME=$(awk -F'=' '/^domain_name/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "")
AWS_REGION=$(awk -F'=' '/^region/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "us-west-2")
HOSTED_ZONE_ID=$(awk -F'=' '/^route53_zone_id/ {gsub(/[" ]/, "", $2); gsub(/#.*/, "", $2); print $2}' terraform.tfvars 2>/dev/null || echo "")

# Set the cell names
export CELL_1=eks-cell-az1
export CELL_2=eks-cell-az2
export CELL_3=eks-cell-az3

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
  echo -e "${BLUE}[INFO] $1${NC}"
}

success() {
  echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
  echo -e "${RED}[ERROR] $1${NC}"
}

# Function to check EKS clusters
check_eks_clusters() {
  info "=== CHECKING EKS CLUSTERS ==="
  
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    echo -n "Checking EKS cluster $cell_name: "
    if aws eks describe-cluster --name "$cell_name" --region "$AWS_REGION" >/dev/null 2>&1; then
      local status=$(aws eks describe-cluster --name "$cell_name" --region "$AWS_REGION" --query 'cluster.status' --output text)
      success "EXISTS (Status: $status)"
    else
      warn "NOT FOUND"
    fi
  done
  echo ""
}

# Function to check Kubernetes resources
check_k8s_resources() {
  info "=== CHECKING KUBERNETES RESOURCES ==="
  
  # Update kubeconfig first
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    
    if aws eks describe-cluster --name "$cell_name" --region "$AWS_REGION" >/dev/null 2>&1; then
      aws eks update-kubeconfig --name "$cell_name" --region "$AWS_REGION" --alias "$cell_name" >/dev/null 2>&1 || true
    fi
  done
  
  local resource_types=("deployments" "services" "ingress")
  
  for type in "${resource_types[@]}"; do
    info "Checking $type:"
    
    for i in {1..3}; do
      local cell="cell$i"
      local cell_var="CELL_$i"
      local context_var="${!cell_var}"
      
      if kubectl config get-contexts "$context_var" >/dev/null 2>&1; then
        local resource_name=""
        case "$type" in
          "deployments") resource_name="${cell}-app" ;;
          "services") resource_name="${cell}-service" ;;
          "ingress") resource_name="${cell}-ingress" ;;
        esac
        
        echo -n "  $context_var/$resource_name: "
        if kubectl get "$type" "$resource_name" --context "$context_var" >/dev/null 2>&1; then
          success "EXISTS"
        else
          warn "NOT FOUND"
        fi
      else
        echo -n "  $context_var: "
        error "CONTEXT NOT AVAILABLE"
      fi
    done
    echo ""
  done
}

# Function to check ALBs
check_albs() {
  info "=== CHECKING APPLICATION LOAD BALANCERS ==="
  
  local albs=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[?contains(LoadBalancerName, `eks-cell`)].{Name:LoadBalancerName,State:State.Code,DNS:DNSName}' --output table 2>/dev/null || echo "")
  
  if [ -n "$albs" ] && [ "$albs" != "[]" ]; then
    echo "$albs"
  else
    warn "No ALBs found with 'eks-cell' in the name"
  fi
  echo ""
}

# Function to check Route53 records
check_route53_records() {
  info "=== CHECKING ROUTE53 RECORDS ==="
  
  if [ -n "$HOSTED_ZONE_ID" ] && [ -n "$DOMAIN_NAME" ]; then
    info "Checking hosted zone $HOSTED_ZONE_ID for domain $DOMAIN_NAME"
    
    local records=$(aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --query "ResourceRecordSets[?contains(Name,'$DOMAIN_NAME')].{Name:Name,Type:Type,TTL:TTL}" --output table 2>/dev/null || echo "")
    
    if [ -n "$records" ] && [ "$records" != "[]" ]; then
      echo "$records"
    else
      warn "No Route53 records found for domain $DOMAIN_NAME"
    fi
  else
    warn "Domain name or hosted zone ID not found in terraform.tfvars"
  fi
  echo ""
}

# Function to check IAM resources
check_iam_resources() {
  info "=== CHECKING IAM RESOURCES ==="
  
  # Check for load balancer controller policy
  echo -n "Load Balancer Controller Policy: "
  if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/eks-cell-lb-controller" >/dev/null 2>&1; then
    success "EXISTS"
  else
    warn "NOT FOUND"
  fi
  
  # Check for load balancer controller roles
  for i in {1..3}; do
    local role_name="eks-cell-az${i}-lb-controller"
    echo -n "Role $role_name: "
    if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
      success "EXISTS"
    else
      warn "NOT FOUND"
    fi
  done
  echo ""
}

# Function to check VPC resources
check_vpc_resources() {
  info "=== CHECKING VPC RESOURCES ==="
  
  # Find VPCs with cell-related tags
  local vpcs=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=*cell*" --query 'Vpcs[].{VpcId:VpcId,Name:Tags[?Key==`Name`].Value|[0],State:State}' --output table 2>/dev/null || echo "")
  
  if [ -n "$vpcs" ] && [ "$vpcs" != "[]" ]; then
    echo "$vpcs"
  else
    warn "No VPCs found with 'cell' in the name tag"
  fi
  echo ""
}

# Function to check CloudWatch Log Groups
check_cloudwatch_logs() {
  info "=== CHECKING CLOUDWATCH LOG GROUPS ==="
  
  for i in {1..3}; do
    local cell_var="CELL_$i"
    local cell_name="${!cell_var}"
    local log_group_name="/aws/eks/${cell_name}/cluster"
    
    echo -n "Log Group $log_group_name: "
    if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --region "$AWS_REGION" 2>/dev/null | grep -q "$log_group_name"; then
      success "EXISTS"
    else
      warn "NOT FOUND"
    fi
  done
  echo ""
}

# Function to check Terraform state
check_terraform_state() {
  info "=== CHECKING TERRAFORM STATE ==="
  
  if [ -f "terraform.tfstate" ]; then
    local resource_count=$(terraform state list 2>/dev/null | wc -l || echo "0")
    success "Terraform state file exists with $resource_count resources"
    
    # Show key resources
    info "Key resources in state:"
    terraform state list 2>/dev/null | grep -E "(eks_cell|route53|lb_controller)" | head -10 || true
  else
    warn "No terraform.tfstate file found"
  fi
  echo ""
}

# Main execution
main() {
  info "=== RESOURCE VERIFICATION BEFORE CLEANUP ==="
  info "Configuration: Domain=$DOMAIN_NAME, Region=$AWS_REGION"
  echo ""
  
  # Check if terraform.tfvars exists
  if [ ! -f "terraform.tfvars" ]; then
    error "terraform.tfvars file not found. Please run this script from the directory containing terraform.tfvars"
    exit 1
  fi
  
  # Check AWS CLI configuration
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error "AWS CLI not properly configured. Please configure AWS credentials."
    exit 1
  fi
  
  # Run all checks
  check_terraform_state
  check_eks_clusters
  check_k8s_resources
  check_albs
  check_route53_records
  check_iam_resources
  check_vpc_resources
  check_cloudwatch_logs
  
  info "=== VERIFICATION COMPLETED ==="
  warn "Review the above output before running cleanup-infrastructure-updated.sh"
}

# Execute the main function
main "$@"
