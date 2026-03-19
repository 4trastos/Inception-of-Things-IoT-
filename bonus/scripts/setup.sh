#!/bin/bash
set -e

GITLAB_NS="gitlab"
ARGOCD_NS="argocd"
DEV_NS="dev"

echo "==> ⚙️ Creando cluster K3d... ⚙️"
k3d cluster create iot \
    --api-port 6443 \
    -p "8080:80@loadbalancer" \
    -p "8888:8888@loadbalancer" \
    -p "8929:8929@loadbalancer"

echo "==> ⚠️ Esperando a que el cluster esté listo... ⚠️"
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "==> ⚙️ Configurando kubeconfig para vagrant... ⚙️"
mkdir -p /home/vagrant/.kube
k3d kubeconfig get iot > /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
export KUBECONFIG=/home/vagrant/.kube/config

echo "==> ⚙️ Creando namespaces... ⚙️"
kubectl create namespace $GITLAB_NS
kubectl create namespace $ARGOCD_NS
kubectl create namespace $DEV_NS

echo "==> ⚙️ Desplegando GitLab CE... ⚙️"
kubectl apply -f /vagrant/confs/gitlab.yaml

echo "==> ⚠️ Esperando a que GitLab arranque (puede tardar 5 min)... ⚠️"
kubectl wait --for=condition=Ready pod \
    -l app=gitlab \
    -n $GITLAB_NS \
    --timeout=600s

echo "==> ⚙️ Instalando Argo CD... ⚙️"
kubectl apply -n $ARGOCD_NS --server-side \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> ⚠️ Esperando a que Argo CD arranque... ⚠️"
kubectl wait --for=condition=Ready pods --all \
    -n $ARGOCD_NS \
    --timeout=300s

echo "==> ⚙️ Configurando repositorio de GitLab en Argo CD... ⚙️"
kubectl apply -f /vagrant/confs/argocd-gitlab-secret.yaml

echo "==> ⚙️ Aplicando la Application de Argo CD... ⚙️"
kubectl apply -f /vagrant/confs/argocd-app.yaml

echo "==> ⚠️ Contrasena inicial de Argo CD: ⚠️"
kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 -d
echo ""

echo "==> 🟢 setup.sh completado 🟢"
echo "==> GitLab disponible en: http://192.168.56.110:8929"
echo "==> Usuario: root  Contrasena: GitLabAdmin42!"