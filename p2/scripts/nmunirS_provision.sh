#!/bin/bash
sudo apt-get update
sudo apt-get install -y curl apt-transport-https ca-certificates gnupg ufw
sudo ufw disable

#Sometimes the google key retrieval can fail, make sure there are no duplicates
sudo rm -f /usr/share/keyrings/cloud.google.gpg

#Install kubectl through google-cli
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update
sudo apt-get install -y google-cloud-cli
sudo apt-get update
sudo apt-get install -y kubectl

#Install docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker vagrant

#Install k3s in server mode (need multiple try, can randomly fail)
for i in {1..3}; do
  if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --token 12345 --node-ip=192.168.56.110 --flannel-iface=eth1 --docker --disable traefik" sh -s; then
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

#Setup config for kubectl
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.bashrc
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> /home/vagrant/.profile
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

#Make sure k3s is ready
timeout 300 bash -c 'until kubectl get nodes | grep -q "Ready"; do echo "Waiting for k3s to be ready..."; sleep 5; done'

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.3/deploy/static/provider/cloud/deploy.yaml

#Wait for nginx controller to be ready
sleep 10

kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=admission-webhook --timeout=180s


#Build Docker images for our apps
docker build -t app1:latest /vagrant/confs/app1/
docker build -t app2:latest /vagrant/confs/app2/
docker build -t app3:latest /vagrant/confs/app3/

#Apply deployments:
kubectl apply -f /vagrant/confs/app1/deployment.yaml
kubectl apply -f /vagrant/confs/app2/deployment.yaml
kubectl apply -f /vagrant/confs/app3/deployment.yaml

#Apply services:
kubectl apply -f /vagrant/confs/app1/service.yaml
kubectl apply -f /vagrant/confs/app2/service.yaml
kubectl apply -f /vagrant/confs/app3/service.yaml

kubectl apply -f /vagrant/confs/ingress.yaml
