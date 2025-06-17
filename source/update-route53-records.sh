#!/bin/bash

# This script updates Route53 records with the actual ALB DNS names and zone IDs
# Run this script after the ALBs have been created by the AWS Load Balancer Controller

# Set environment variables
export CELL_1=eks-cell-az1
export CELL_2=eks-cell-az2
export CELL_3=eks-cell-az3
export AWS_REGION=us-west-2  # Set your AWS region explicitly

# Wait for ALBs to be created
echo "Waiting for ALBs to be created by AWS Load Balancer Controller..."
sleep 120

# Get the ALB information for cell1
CELL1_ALB_INFO=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${CELL_1}-alb')].{DNSName:DNSName,CanonicalHostedZoneId:CanonicalHostedZoneId}" --output json)
CELL1_ALB_DNS_NAME=$(echo $CELL1_ALB_INFO | jq -r '.[0].DNSName')
CELL1_ALB_ZONE_ID=$(echo $CELL1_ALB_INFO | jq -r '.[0].CanonicalHostedZoneId')

# Get the ALB information for cell2
CELL2_ALB_INFO=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${CELL_2}-alb')].{DNSName:DNSName,CanonicalHostedZoneId:CanonicalHostedZoneId}" --output json)
CELL2_ALB_DNS_NAME=$(echo $CELL2_ALB_INFO | jq -r '.[0].DNSName')
CELL2_ALB_ZONE_ID=$(echo $CELL2_ALB_INFO | jq -r '.[0].CanonicalHostedZoneId')

# Get the ALB information for cell3
CELL3_ALB_INFO=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${CELL_3}-alb')].{DNSName:DNSName,CanonicalHostedZoneId:CanonicalHostedZoneId}" --output json)
CELL3_ALB_DNS_NAME=$(echo $CELL3_ALB_INFO | jq -r '.[0].DNSName')
CELL3_ALB_ZONE_ID=$(echo $CELL3_ALB_INFO | jq -r '.[0].CanonicalHostedZoneId')

# Get the Route53 zone ID
ZONE_ID=$(terraform output -raw route53_zone_id)
DOMAIN_NAME=$(terraform output -raw domain_name)

# Update the Route53 records for cell1
echo "Updating Route53 records for cell1..."
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cell1.'$DOMAIN_NAME'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$CELL1_ALB_ZONE_ID'",
          "DNSName": "'$CELL1_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

# Update the Route53 records for cell2
echo "Updating Route53 records for cell2..."
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cell2.'$DOMAIN_NAME'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$CELL2_ALB_ZONE_ID'",
          "DNSName": "'$CELL2_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

# Update the Route53 records for cell3
echo "Updating Route53 records for cell3..."
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cell3.'$DOMAIN_NAME'",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$CELL3_ALB_ZONE_ID'",
          "DNSName": "'$CELL3_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

# Update the weighted Route53 records
echo "Updating weighted Route53 records..."
aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'$DOMAIN_NAME'",
        "Type": "A",
        "SetIdentifier": "cell1",
        "Weight": 33,
        "AliasTarget": {
          "HostedZoneId": "'$CELL1_ALB_ZONE_ID'",
          "DNSName": "'$CELL1_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'$DOMAIN_NAME'",
        "Type": "A",
        "SetIdentifier": "cell2",
        "Weight": 33,
        "AliasTarget": {
          "HostedZoneId": "'$CELL2_ALB_ZONE_ID'",
          "DNSName": "'$CELL2_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'$DOMAIN_NAME'",
        "Type": "A",
        "SetIdentifier": "cell3",
        "Weight": 34,
        "AliasTarget": {
          "HostedZoneId": "'$CELL3_ALB_ZONE_ID'",
          "DNSName": "'$CELL3_ALB_DNS_NAME'",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}'

echo "Route53 records updated successfully!"