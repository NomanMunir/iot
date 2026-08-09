#!/bin/bash

echo "Deleting ArgoCD application..."
kubectl delete -f ../confs/application.yaml 2>/dev/null || true

echo "Deleting namespaces (this can take a minute)..."
kubectl delete namespace dev 2>/dev/null || true
kubectl delete namespace argocd 2>/dev/null || true

echo "Deleting K3d cluster..."
k3d cluster delete iot-cluster 2>/dev/null || true

rm -f argocd-password.txt

echo "Cleaned up!"
