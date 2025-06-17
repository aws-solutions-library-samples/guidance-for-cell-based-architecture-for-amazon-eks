#!/bin/bash

# Set the cell names
export CELL_1=eks-cell-az1
export CELL_2=eks-cell-az2
export CELL_3=eks-cell-az3
export AWS_REGION=us-west-2

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
