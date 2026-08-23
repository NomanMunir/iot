#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFS_DIR="${SCRIPT_DIR}/../confs"

echo "=========================================="
echo "1. Installing Prerequisites (Docker, Curl)"
echo "=========================================="
sudo apt-get update
sudo apt-get install -y docker.io curl ca-certificates
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" 2>/dev/null || true

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
    k3d cluster create iot-cluster --api-port 6550 --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"
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

# Enable insecure mode for Argo CD server so Ingress can route HTTP without TLS redirect loops
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || true

echo "Waiting for Argo CD to start..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "=========================================="
echo "6. Extracting Argo CD Password"
echo "=========================================="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > "${SCRIPT_DIR}/argocd-password.txt" || echo "Secret not found (password may have been changed)"
echo "Argo CD admin password saved to: ${SCRIPT_DIR}/argocd-password.txt"

echo "=========================================="
echo "7. Deploying Local GitLab & Ingresses"
echo "=========================================="
kubectl apply -f "${CONFS_DIR}/gitlab-deployment.yaml"
kubectl apply -f "${CONFS_DIR}/gitlab-service.yaml"
kubectl apply -f "${CONFS_DIR}/gitlab-ingress.yaml"
kubectl apply -f "${CONFS_DIR}/argocd-ingress.yaml"

echo "Waiting for GitLab to start (THIS CAN TAKE 5-10 MINUTES)..."
kubectl wait --for=condition=available --timeout=900s deployment/gitlab -n gitlab || echo "GitLab is still starting in the background..."

echo "=========================================="
echo "8. Applying Argo CD Application"
echo "=========================================="
kubectl apply -f "${CONFS_DIR}/application.yaml"

echo ""
echo "=========================================="
echo "🎉 Bonus Setup Complete!"
echo "=========================================="
echo "Make sure your /etc/hosts includes:"
echo "127.0.0.1   argocd.local gitlab.local"
echo ""
echo "Access URLs:"
echo "👉 Argo CD UI: http://argocd.local:8080 (Username: admin, Password: $(cat "${SCRIPT_DIR}/argocd-password.txt" 2>/dev/null || echo 'see argocd-password.txt'))"
echo "👉 GitLab UI:  http://gitlab.local:8080"
echo "👉 App URL:    http://localhost:8080"
echo "=========================================="
