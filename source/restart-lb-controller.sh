#!/bin/bash

# Restart AWS Load Balancer Controller pods
echo "Restarting AWS Load Balancer Controller pods..."
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_1
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_2
kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --context $CELL_3

echo "AWS Load Balancer Controller pods restarted!"
