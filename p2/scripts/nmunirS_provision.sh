#!/bin/sh
set -euo pipefail

echo "192.168.56.110 nmunirS" >> /etc/hosts

apk update
apk add curl chrony iptables coreutils

rc-update add chronyd default
rc-service chronyd start
sleep 3

IFACE="$(ip -o addr show | grep '192\.168\.56\.' | awk '{print $2}' | head -n 1)"
IFACE="${IFACE:-eth1}"

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

echo "Waiting for K3s server API to be ready..."
timeout 120 sh -c 'until curl -k -s https://192.168.56.110:6443/ping | grep -q "pong"; do sleep 2; done'

echo "Waiting for k3s.yaml to be generated..."
until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 2; done

if ! command -v kubectl >/dev/null 2>&1; then
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
fi

chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

timeout 300 sh -c 'until kubectl get nodes | grep -q "Ready"; do echo "Waiting for k3s to be ready..."; sleep 5; done'

kubectl apply -f /vagrant/confs/app1/deployment.yaml
kubectl apply -f /vagrant/confs/app2/deployment.yaml
kubectl apply -f /vagrant/confs/app3/deployment.yaml

kubectl apply -f /vagrant/confs/app1/service.yaml
kubectl apply -f /vagrant/confs/app2/service.yaml
kubectl apply -f /vagrant/confs/app3/service.yaml

kubectl apply -f /vagrant/confs/ingress.yaml
