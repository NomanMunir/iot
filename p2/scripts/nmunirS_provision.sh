#!/bin/sh
set -euo pipefail

# Add local DNS entries to prevent reverse DNS lookup timeouts
echo "192.168.56.110 nmunirS" >> /etc/hosts

# Update package index and install required packages for Alpine
apk update
apk add curl chrony iptables coreutils

# Ensure time is synchronized (critical for TLS certificates)
rc-update add chronyd default
rc-service chronyd start
sleep 3

# Dynamically detect interface matching 192.168.56.x (fallback to eth1)
IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

# Install k3s in server mode (host-gw avoids nested virtualization MTU drops)
for i in $(seq 1 3); do
	if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-backend=host-gw --flannel-iface=${IFACE}" sh -s -; then
	break
  else
    if [ "$i" -eq 3 ]; then
	echo "Failed to install k3s after 3 attempts"
	exit 1
    fi
    sleep 10
  fi
done

# Wait for K3s server API to respond
echo "Waiting for K3s server API to be ready..."
timeout 120 sh -c 'until curl -k -s https://192.168.56.110:6443/ping | grep -q "pong"; do sleep 2; done'

# Wait for kubeconfig to be generated
echo "Waiting for k3s.yaml to be generated..."
until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done

# K3s ships with kubectl functionality; expose it as `kubectl` if needed.
if ! command -v kubectl >/dev/null 2>&1; then
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
fi

# Setup config for kubectl
chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Make sure k3s node is ready
timeout 300 sh -c 'until kubectl get nodes | grep -q "Ready"; do echo "Waiting for k3s to be ready..."; sleep 5; done'

# Apply config + workloads
kubectl apply -f /vagrant/confs/app1/configmap.yaml
kubectl apply -f /vagrant/confs/app2/configmap.yaml
kubectl apply -f /vagrant/confs/app3/configmap.yaml

kubectl apply -f /vagrant/confs/app1/deployment.yaml
kubectl apply -f /vagrant/confs/app2/deployment.yaml
kubectl apply -f /vagrant/confs/app3/deployment.yaml

kubectl apply -f /vagrant/confs/app1/service.yaml
kubectl apply -f /vagrant/confs/app2/service.yaml
kubectl apply -f /vagrant/confs/app3/service.yaml

kubectl apply -f /vagrant/confs/ingress.yaml
