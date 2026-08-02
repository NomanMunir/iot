#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl ca-certificates

# Dynamically detect interface matching 192.168.56.x (fallback to eth1)
IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

# Install k3s in server mode (need multiple try, can randomly fail)
for i in {1..3}; do
	if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=${IFACE}" sh -s -; then
	break
  else
    if [ $i -eq 3 ]; then
	echo "Failed to install k3s after 3 attempts"
	exit 1
    fi
    sleep 10
  fi
done

sleep 15

# K3s ships with kubectl functionality; expose it as `kubectl` if needed.
if ! command -v kubectl >/dev/null 2>&1; then
  sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
fi

# Setup config for kubectl
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

#Make sure k3s is ready
timeout 300 bash -c 'until kubectl get nodes | grep -q "Ready"; do echo "Waiting for k3s to be ready..."; sleep 5; done'

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
