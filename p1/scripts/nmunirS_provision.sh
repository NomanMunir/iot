#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl ca-certificates ufw openssl
sudo ufw disable

TOKEN_FILE="/vagrant/node-token"
READY_FILE="/vagrant/node-token.ready"

# Ensure worker doesn't consume a stale token.
sudo rm -f "$READY_FILE"

# Generate and publish a join token for the worker (synced to host via /vagrant).
K3S_TOKEN_VALUE="$(openssl rand -hex 24)"
echo -n "$K3S_TOKEN_VALUE" | sudo tee "$TOKEN_FILE" >/dev/null

# Install k3s in server mode (need multiple try, can randomly fail)
for i in {1..3}; do
	if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --token ${K3S_TOKEN_VALUE} --node-ip=192.168.56.110 --flannel-iface=eth1" sh -s -; then
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

#Setup config for kubectl
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile

# Signal that the token is valid and server is ready.
echo "ready" | sudo tee "$READY_FILE" >/dev/null

