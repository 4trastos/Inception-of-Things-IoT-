#!/bin/bash
set -e

echo "==> ⚙️ Creando cluster K3d... ⚙️"
k3d cluster create iot \
    --api-port 6443 \
    -p "8080:80@loadbalancer" \
    -p "8888:8888@loadbalancer"

echo "==> ⚠️ Esperando a que el cluster esté listo... ⚠️"
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "==> ⚙️ Creando namespaces... ⚙️"
kubectl create namespace argocd
kubectl create namespace dev

echo "==> ⚙️ Instalando Argo CD... ⚙️"
kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> ⚠️ Esperando a que Argo CD arranque... ⚠️"
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "==> ⚠️ Aplicando la Application de Argo CD... ⚠️"
kubectl apply -f /vagrant/confs/argocd-app.yaml

echo "==> ⚠️ Contrasena inicial de Argo CD: ⚠️"
kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 -d
echo ""

echo "==> 🟢 setup.sh completado 🟢"