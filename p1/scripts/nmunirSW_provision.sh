#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y curl ca-certificates ufw
sudo ufw disable

TOKEN_FILE="/vagrant/node-token"
READY_FILE="/vagrant/node-token.ready"

# Wait until the server has installed k3s and published a fresh token.
for i in {1..60}; do
  if [ -f "$READY_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    break
  fi
  sleep 5
done

if [ ! -f "$READY_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
  echo "Timed out waiting for server token at $TOKEN_FILE"
  exit 1
fi

# Strip CR/LF in case host filesystem introduces Windows line endings.
K3S_TOKEN_VALUE="$(tr -d '\r\n' < "$TOKEN_FILE")"

# Dynamically detect interface matching 192.168.56.x (fallback to eth1)
IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

# Verify connection to server API endpoint
echo "Verifying connection to K3s server at https://192.168.56.110:6443..."
timeout 60 bash -c 'until curl -k -s https://192.168.56.110:6443/ping | grep -q "pong"; do sleep 2; done'

#Install k3s in agent mode (need multiple try, can randomly fail)
for i in {1..3}; do
	if curl -sfL https://get.k3s.io | K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="${K3S_TOKEN_VALUE}" INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=${IFACE}" sh -s -; then
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
