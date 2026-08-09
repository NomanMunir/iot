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
echo "3. Checking K3d Cluster"
echo "=========================================="
if ! k3d cluster list iot-cluster >/dev/null 2>&1; then
    echo "Cluster not found. Creating new iot-cluster..."
    k3d cluster create iot-cluster --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"
else
    echo "Cluster iot-cluster already exists! Skipping creation."
fi
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "=========================================="
echo "4. Creating Namespaces (argocd, dev, gitlab)"
echo "=========================================="
kubectl get namespace argocd >/dev/null 2>&1 || kubectl create namespace argocd
kubectl get namespace dev >/dev/null 2>&1 || kubectl create namespace dev
kubectl get namespace gitlab >/dev/null 2>&1 || kubectl create namespace gitlab

echo "=========================================="
echo "5. Installing Argo CD"
echo "=========================================="
if ! kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
    echo "Argo CD is already installed, skipping creation."
fi
echo "Waiting for Argo CD to start..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "=========================================="
echo "6. Deploying Local GitLab"
echo "=========================================="
kubectl apply -f ../confs/gitlab-deployment.yaml
kubectl apply -f ../confs/gitlab-service.yaml
kubectl apply -f ../confs/gitlab-ingress.yaml

echo "Waiting for GitLab to start (THIS CAN TAKE 5-10 MINUTES)..."
kubectl wait --for=condition=available --timeout=900s deployment/gitlab -n gitlab || echo "GitLab is still starting in the background..."

echo "=========================================="
echo "7. Final Instructions"
echo "=========================================="
echo "1. Run: sudo nano /etc/hosts and add '127.0.0.1 gitlab.local'"
echo "2. Access GitLab at: http://gitlab.local:8080"
echo "3. Create a public repository named 'iot-nmunir' in GitLab"
echo "4. Push your yaml files to your local GitLab"
echo "5. Tell ArgoCD to sync from GitLab: kubectl apply -f ../confs/application.yaml"
echo "=========================================="
