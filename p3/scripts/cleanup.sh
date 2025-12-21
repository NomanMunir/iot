#!/bin/bash

kubectl delete -f argocd/application.yaml 2>/dev/null || true

k3d cluster delete iot-cluster

rm -f argocd-password.txt

echo "Cleaned up!"
