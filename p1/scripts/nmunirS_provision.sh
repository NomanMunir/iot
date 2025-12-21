#!/bin/bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates ufw
sudo ufw disable

#Install k3s in server mode (need multiple try, can randomly fail)
for i in {1..3}; do
  if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --token 12345 --node-ip=192.168.56.110 --flannel-iface=eth1" sh -s; then
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
