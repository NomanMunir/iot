#!/bin/bash

k3d cluster create iot-cluster --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"

kubectl wait --for=condition=Ready nodes --all --timeout=300s

kubectl create namespace argocd
kubectl create namespace dev

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argocd-password.txt
echo "Argo CD admin password saved to: argocd-password.txt"

echo "1. Run: kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "2. Open: https://localhost:8081"
echo "3. Login with admin / $(cat argocd-password.txt)"

echo "To apply your application:"
echo "kubectl apply -f confs/application.yaml"
