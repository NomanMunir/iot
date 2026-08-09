#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "1. Installing Prerequisites (Docker, Curl)"
echo "=========================================="
sudo apt-get update
sudo apt-get install -y docker.io curl ca-certificates
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "=========================================="
echo "2. Installing K3d and Kubectl"
echo "=========================================="
if ! command -v kubectl >/dev/null 2>&1; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

if ! command -v k3d >/dev/null 2>&1; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

echo "=========================================="
echo "3. Creating K3d Cluster"
echo "=========================================="
k3d cluster delete iot-cluster || true

k3d cluster create iot-cluster --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "=========================================="
echo "4. Creating Namespaces (argocd, dev)"
echo "=========================================="
kubectl create namespace argocd
kubectl create namespace dev

echo "=========================================="
echo "5. Installing Argo CD"
echo "=========================================="
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
    echo "Argo CD is already installed, skipping creation."
fi

echo "Waiting for Argo CD to start (this can take a few minutes)..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "=========================================="
echo "6. Extracting Argo CD Password"
echo "=========================================="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argocd-password.txt
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "Argo CD admin password saved to: argocd-password.txt"
echo "Username: admin"
echo "Password: $(cat argocd-password.txt)"
echo ""
echo "To access Argo CD:"
echo "1. Run this port-forward command in a separate terminal:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "2. Open your browser and go to: https://localhost:8081"
echo ""
echo "To apply your GitOps application, run:"
echo "kubectl apply -f ../confs/application.yaml"
echo "=========================================="
