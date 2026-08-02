#!/bin/sh
set -euo pipefail

# Add local DNS entries to prevent reverse DNS lookup timeouts
echo "192.168.56.110 nmunirS" >> /etc/hosts
echo "192.168.56.111 nmunirSW" >> /etc/hosts

# Update package index and install required packages for Alpine
apk update
apk add curl chrony iptables coreutils

# Ensure time is synchronized (critical for TLS certificates)
rc-update add chronyd default
rc-service chronyd start
sleep 3

# Wait for IP to be assigned
until ip -o addr show | grep -q '192\.168\.56\.110'; do sleep 2; done

# Dynamically detect interface matching 192.168.56.x (fallback to eth1)
IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

# Install k3s in server mode (host-gw avoids nested virtualization MTU drops)
# We securely use the $K3S_TOKEN environment variable provided by Vagrant
for i in $(seq 1 3); do
	if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --token ${K3S_TOKEN} --node-ip=192.168.56.110 --flannel-backend=host-gw --flannel-iface=${IFACE}" sh -s -; then
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

# Setup config for kubectl
chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
