#!/bin/bash
set -e

GITLAB_NS="gitlab"
ARGOCD_NS="argocd"
DEV_NS="dev"
GITLAB_ROOT_PASSWORD="GitLabAdmin42!"
GITLAB_URL="http://gitlab-webservice-default.gitlab.svc.cluster.local:8181"

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

echo "==> ⚙️ Instalando GitLab con Helm... ⚙️"
helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
    --namespace $GITLAB_NS \
    --timeout 600s \
    --set global.hosts.domain=gitlab.local \
    --set global.hosts.externalIP=192.168.56.110 \
    --set global.edition=ce \
    --set global.initialRootPassword=$GITLAB_ROOT_PASSWORD \
    --set certmanager.install=false \
    --set global.ingress.configureCertmanager=false \
    --set global.ingress.tls.enabled=false \
    --set gitlab-runner.install=false \
    --set prometheus.install=false \
    --set grafana.enabled=false \
    --set global.kas.enabled=false \
    --set gitlab.webservice.minReplicas=1 \
    --set gitlab.webservice.maxReplicas=1 \
    --set gitlab.sidekiq.minReplicas=1 \
    --set gitlab.sidekiq.maxReplicas=1 \
    --set gitlab.gitlab-shell.minReplicas=1 \
    --set gitlab.gitlab-shell.maxReplicas=1 \
    --set redis.master.persistence.enabled=false \
    --set postgresql.primary.persistence.enabled=false \
    --set minio.persistence.enabled=false

echo "==> ⚠️ Esperando a que GitLab arranque (puede tardar 5-10 min)... ⚠️"
kubectl wait --for=condition=Ready pods \
    -l app=webservice \
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
echo "==> GitLab: http://192.168.56.110:8080  usuario: root  pass: $GITLAB_ROOT_PASSWORD"