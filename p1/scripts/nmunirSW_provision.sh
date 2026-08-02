#!/bin/sh
set -euo pipefail

echo "192.168.56.110 nmunirS" >> /etc/hosts
echo "192.168.56.111 nmunirSW" >> /etc/hosts

apk update
apk add curl chrony iptables coreutils

# Ensure time is synchronized (critical for TLS certificates)
rc-update add chronyd default
rc-service chronyd start
sleep 3

# Dynamically detect interface
IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

echo "Waiting for K3s server API to be reachable at https://192.168.56.110:6443..."
timeout 300 sh -c 'until curl -k -s https://192.168.56.110:6443/ping | grep -q "pong"; do sleep 5; done'

# Install k3s in agent mode
for i in $(seq 1 3); do
	if curl -sfL https://get.k3s.io | K3S_URL="https://192.168.56.110:6443" K3S_TOKEN="${K3S_TOKEN}" INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=${IFACE}" sh -s -; then
	break
  else
    if [ "$i" -eq 3 ]; then
	echo "Failed to install k3s agent after 3 attempts"
	exit 1
    fi
    sleep 10
  fi
done

sleep 10
