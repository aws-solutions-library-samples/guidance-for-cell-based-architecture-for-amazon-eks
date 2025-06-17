# Troubleshooting Guide for Cell-Based EKS Architecture

This document provides troubleshooting guidance for common issues encountered when deploying and managing the Cell-Based EKS Architecture.

## Table of Contents

- [Terraform Init Errors](#terraform-init-errors)
- [AWS Load Balancer Controller Errors](#aws-load-balancer-controller-errors)
- [ALBs Not Being Created](#albs-not-being-created)
- [IAM Role Already Exists Error](#iam-role-already-exists-error)
- [IAM Role Trust Relationship Issues](#iam-role-trust-relationship-issues)
- [ALB Data Source Error](#alb-data-source-error)
- [Route53 Alias Record Errors](#route53-alias-record-errors)
- [Troubleshooting Destroy Process](#troubleshooting-destroy-process)

## Terraform Init Errors

If you encounter errors during `terraform init`, ensure that:

1. You have the required providers in your `versions.tf` file:
   ```hcl
   terraform {
     required_version = ">= 1.0"
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = ">= 5.0"
       }
       kubernetes = {
         source  = "hashicorp/kubernetes"
         version = ">= 2.10"
       }
       helm = {
         source  = "hashicorp/helm"
         version = ">= 2.4"
       }
     }
   }
   ```

2. There are no duplicate resource definitions across files.

3. All required modules are accessible:
   ```bash
   # Check if modules can be downloaded
   terraform get -update
   ```

4. Your AWS credentials are properly configured:
   ```bash
   aws sts get-caller-identity
   ```

## AWS Load Balancer Controller Errors

If you encounter errors related to the AWS Load Balancer Controller Helm chart:

1. Make sure the `set` parameter is formatted correctly:
   ```hcl
   lb_controller_helm_config_cell1 = {
     set = [
       {
         name  = "clusterName"
         value = module.eks_cell1.cluster_name
       },
       # Other settings...
     ]
   }
   ```

2. For special characters in Helm parameter names, use escape sequences:
   ```hcl
   {
     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
     value = aws_iam_role.lb_controller_role_cell1.arn
   }
   ```

3. For node selectors with dots in the key name:
   ```hcl
   {
     name  = "nodeSelector.topology\\.kubernetes\\.io/zone"
     value = local.azs[0]
   }
   ```

4. Check if the AWS Load Balancer Controller is installed correctly:
   ```bash
   helm list -n kube-system --context ${CELL_1}
   ```

5. Verify the AWS Load Balancer Controller CRDs are installed:
   ```bash
   kubectl get crds -n kube-system | grep alb --context ${CELL_1}
   ```

## ALBs Not Being Created

If you don't see ALBs being created after deploying the ingress resources:

1. **Check if the AWS Load Balancer Controller pods are running**:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context ${CELL_1}
   ```

2. **Check the AWS Load Balancer Controller logs**:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context ${CELL_1}
   ```

3. **Verify that the ingress resources are properly configured**:
   ```bash
   kubectl get ingress -n default --context ${CELL_1} -o yaml
   ```

4. **Ensure that there are actual pods running that match the service selector**:
   ```bash
   kubectl get pods -n default -l app=cell1-app --context ${CELL_1}
   ```

5. **Make sure the ingress annotations are correct**:
   - The `alb.ingress.kubernetes.io/listen-ports` should include both HTTP and HTTPS: `[{"HTTP":80},{"HTTPS":443}]`
   - The `alb.ingress.kubernetes.io/healthcheck-protocol` should be `HTTP` for initial testing
   - The `alb.ingress.kubernetes.io/healthcheck-path` should be `/` for nginx

6. **Check if the IAM roles have the necessary permissions**:
   ```bash
   aws iam get-role --role-name eks-cell-az1-lb-controller
   aws iam list-attached-role-policies --role-name eks-cell-az1-lb-controller
   ```

7. **Verify that the service account has the correct annotations**:
   ```bash
   kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml --context ${CELL_1}
   ```

8. **Check if the security groups allow traffic**:
   ```bash
   # Get the security group IDs
   aws eks describe-cluster --name ${CELL_1} --query "cluster.resourcesVpcConfig.securityGroupIds" --output text
   
   # Check the security group rules
   aws ec2 describe-security-groups --group-ids <security-group-id>
   ```

## IAM Role Already Exists Error

If you encounter an error like:
```
Error: creating IAM Role (eks-cell-az2-lb-controller): operation error IAM: CreateRole, https response error StatusCode: 409, RequestID: b05cf630-5c24-48d7-ae42-f0f2f69e7304, EntityAlreadyExists: Role with name eks-cell-az2-lb-controller already exists.
```

This means the IAM roles for the AWS Load Balancer Controller already exist. You have two options:

1. **Option 1**: Import the existing roles into your Terraform state:
   ```bash
   terraform import aws_iam_role.lb_controller_role_cell1 eks-cell-az1-lb-controller
   terraform import aws_iam_role.lb_controller_role_cell2 eks-cell-az2-lb-controller
   terraform import aws_iam_role.lb_controller_role_cell3 eks-cell-az3-lb-controller
   ```

2. **Option 2**: Delete the existing roles and let Terraform create new ones:
   ```bash
   aws iam delete-role --role-name eks-cell-az1-lb-controller
   aws iam delete-role --role-name eks-cell-az2-lb-controller
   aws iam delete-role --role-name eks-cell-az3-lb-controller
   ```

Option 1 is safer as it preserves any existing configurations, while Option 2 gives you a clean slate but might disrupt existing services temporarily.

## IAM Role Trust Relationship Issues

If you see errors like:
```
WebIdentityErr: failed to retrieve credentials
caused by: AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

This indicates an issue with the IAM role trust relationship. With our updated configuration using direct `aws_iam_role` resources, the trust relationship is explicitly defined:

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cell1.oidc_provider, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(module.eks_cell1.oidc_provider, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(module.eks_cell1.oidc_provider, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }
  ]
})
```

If you're still having issues:

1. **Check the trust relationship of the IAM role**:
   ```bash
   aws iam get-role --role-name eks-cell-az1-lb-controller --query 'Role.AssumeRolePolicyDocument' --output text
   ```

2. **Verify the OIDC provider exists**:
   ```bash
   OIDC_PROVIDER=$(aws eks describe-cluster --name eks-cell-az1 --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
   aws iam list-open-id-connect-providers | grep $OIDC_PROVIDER
   ```

3. **Check the service account annotation**:
   ```bash
   kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml --context ${CELL_1}
   ```

4. **If needed, manually update the trust relationship**:
   ```bash
   # Get the OIDC provider URL
   OIDC_PROVIDER=$(aws eks describe-cluster --name eks-cell-az1 --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   
   # Create trust policy JSON
   cat > trust-policy.json << EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
             "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
           }
         }
       }
     ]
   }
   EOF
   
   # Update the role's trust relationship
   aws iam update-assume-role-policy --role-name eks-cell-az1-lb-controller --policy-document file://trust-policy.json
   ```

## ALB Data Source Error

If you encounter an error like:
```
Error: reading ELBv2 Load Balancers: couldn't find resource
```

This happens because Terraform is trying to find an ALB that doesn't exist yet. The ALB is created by the AWS Load Balancer Controller after the Kubernetes Ingress resource is deployed.

To fix this issue:

1. The Route53 configuration has been updated to use `lifecycle { ignore_changes = [alias] }` for the ALB alias records
2. A script `update-route53-records.sh` has been provided to update the Route53 records with the actual ALB information after they are created
3. Run this script after the ALBs have been created:
   ```bash
   chmod +x update-route53-records.sh
   ./update-route53-records.sh
   ```

4. Verify that the ALBs have been created:
   ```bash
   aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' --output table
   ```

5. If the ALBs are not being created, check the AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context ${CELL_1}
   ```

## Route53 Alias Record Errors

If you encounter errors like:
```
InvalidChangeBatch: [Tried to create an alias that targets eks-cell-az1-alb-c55a6c9a.anycompany.com., type A in zone Z1H1FL5HABSF5, but the alias target name does not lie within the target zone]
```

This happens because:
1. Route53 alias records must point to actual AWS resource DNS names, not to constructed domain names
2. The ALBs created by AWS Load Balancer Controller have AWS-generated DNS names

The solution is:
1. Make sure the Ingress resources are created first and wait for the ALBs to be provisioned
2. Run the `update-route53-records.sh` script to update the Route53 records with the actual ALB information

3. If you're still having issues, manually update the Route53 records:
   ```bash
   # Get the ALB DNS name and zone ID
   ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${CELL_1}-alb')].DNSName" --output text)
   ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(LoadBalancerName, '${CELL_1}-alb')].CanonicalHostedZoneId" --output text)
   
   # Get the Route53 zone ID
   ZONE_ID=$(terraform output -raw route53_zone_id)
   
   # Update the Route53 record
   aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
     "Changes": [
       {
         "Action": "UPSERT",
         "ResourceRecordSet": {
           "Name": "cell1.'$(terraform output -raw domain_name)'",
           "Type": "A",
           "AliasTarget": {
             "HostedZoneId": "'$ALB_ZONE_ID'",
             "DNSName": "'$ALB_DNS_NAME'",
             "EvaluateTargetHealth": true
           }
         }
       }
     ]
   }'
   ```

## Troubleshooting Destroy Process

If you encounter errors during the destroy process related to Kubernetes resources:

1. If you get errors about finalizers on Kubernetes resources:
   ```bash
   kubectl patch ingress cell1-ingress -n default --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' --context ${CELL_1}
   kubectl patch ingress cell2-ingress -n default --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' --context ${CELL_2}
   kubectl patch ingress cell3-ingress -n default --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' --context ${CELL_3}
   ```

2. If you get errors about Kubernetes resources not being found, you can remove them from the Terraform state:
   ```bash
   terraform state rm kubernetes_manifest.cell1_ingress
   terraform state rm kubernetes_manifest.cell2_ingress
   terraform state rm kubernetes_manifest.cell3_ingress
   ```

3. If you get errors about AWS resources being in use, check for dependencies:
   ```bash
   # For example, check if there are any resources using the security groups
   aws ec2 describe-network-interfaces --filters "Name=group-id,Values=<security-group-id>"
   ```

4. If you get errors about IAM roles being in use, check for service accounts using them:
   ```bash
   kubectl get serviceaccounts --all-namespaces -o json | jq '.items[] | select(.metadata.annotations."eks.amazonaws.com/role-arn" != null) | .metadata.annotations."eks.amazonaws.com/role-arn"'
   ```

5. If you get timeout errors during destroy, try increasing the timeout:
   ```bash
   export TF_DESTROY_TIMEOUT=30m
   terraform destroy -auto-approve
   ```

6. If all else fails, you can try to force remove resources from the Terraform state and then manually delete them:
   ```bash
   terraform state rm <resource_address>
   ```