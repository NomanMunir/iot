#!/bin/bash

# Create dedicated namespace
kubectl create namespace gitlab

# Install Gitlab CE using Docker (lighter than Helm on K8s for local VMs)
# Assumes Docker is installed
echo "Starting Gitlab container..."
sudo docker run --detach \
  --hostname gitlab.local \
  --publish 8443:443 --publish 8088:80 --publish 2222:22 \
  --name gitlab \
  --restart always \
  --volume $HOME/gitlab/config:/etc/gitlab \
  --volume $HOME/gitlab/logs:/var/log/gitlab \
  --volume $HOME/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest

echo "Gitlab is starting... this process may take several minutes."
echo "Access Gitlab at http://localhost:8088"
echo "Root password retrieval:"
echo "sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password"

# Prepare Gitlab Config for K3d access (Optional)
# You might need to add 'gitlab.local' to /etc/hosts mapping to 127.0.0.1
