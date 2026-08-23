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
echo "3. Creating K3d Cluster"
echo "=========================================="
k3d cluster delete iot-cluster || true

k3d cluster create iot-cluster --api-port 6550 --port "8080:80@loadbalancer" --port "8443:443@loadbalancer"

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

# Enable insecure mode for Argo CD server so Ingress can route HTTP without TLS redirect loops
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || true

echo "Waiting for Argo CD to start (this can take some time)..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "=========================================="
echo "6. Extracting Argo CD Password"
echo "=========================================="
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > "${SCRIPT_DIR}/argocd-password.txt"

echo "=========================================="
echo "7. Deploying Ingress & Application"
echo "=========================================="
kubectl apply -f "${CONFS_DIR}/argocd-ingress.yaml"
kubectl apply -f "${CONFS_DIR}/application.yaml"

echo ""
echo "=========================================="
echo "🎉 Setup Complete!"
echo "=========================================="
echo "Argo CD admin password saved to: ${SCRIPT_DIR}/argocd-password.txt"
echo "Username: admin"
echo "Password: $(cat "${SCRIPT_DIR}/argocd-password.txt")"
echo ""
echo "Access URLs (ensure '127.0.0.1 argocd.local' is in your /etc/hosts):"
echo "👉 Argo CD UI: http://argocd.local:8080"
echo "👉 App URL:    http://localhost:8080"
echo "=========================================="
