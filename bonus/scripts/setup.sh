#!/bin/bash
set -e

START_TIME=$(date +%s)
show_elapsed() {
    ELAPSED=$(( $(date +%s) - START_TIME ))
    echo "==> ⏱️  Tiempo: $((ELAPSED/60))m $((ELAPSED%60))s"
}

echo "==> ⚙️ Creando cluster K3d..."
k3d cluster create iot \
    --api-port 6443 \
    -p "8080:80@loadbalancer" \
    -p "8888:8888@loadbalancer"

kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "==> ⚙️ Configurando kubeconfig..."
mkdir -p /home/vagrant/.kube
k3d kubeconfig get iot > /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
export KUBECONFIG=/home/vagrant/.kube/config

echo "==> ⚙️ Creando namespaces..."
kubectl create namespace gitlab
kubectl create namespace argocd
kubectl create namespace dev
show_elapsed

echo "==> ⚙️ Instalando Argo CD en paralelo con GitLab..."
kubectl apply -n argocd --server-side \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml &
ARGOCD_PID=$!

echo "==> ⚙️ Instalando GitLab con Helm..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --timeout 600s \
    --set global.hosts.domain=192.168.56.110 \
    --set global.hosts.externalIP=192.168.56.110 \
    --set global.hosts.https=false \
    --set global.hosts.gitlab.name=192.168.56.110 \
    --set global.edition=ce \
    --set certmanager-issuer.email=admin@gitlab.local \
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
show_elapsed

echo "==> ⚠️ Esperando a que GitLab arranque (puede tardar 10 min)..."
kubectl wait --for=condition=Ready pod \
    -l app=webservice \
    -n gitlab \
    --timeout=900s
show_elapsed

echo "==> ⚠️ Esperando a que Argo CD arranque..."
wait $ARGOCD_PID
kubectl wait --for=condition=Ready pods --all \
    -n argocd \
    --timeout=300s
show_elapsed

echo "==> 🔑 Contraseña de GitLab (usuario: root):"
kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab \
    -o jsonpath='{.data.password}' | base64 -d
echo ""

echo "==> ⚙️ Configurando Argo CD..."
kubectl apply -f /vagrant/confs/argocd-gitlab-secret.yaml
kubectl apply -f /vagrant/confs/argocd-app.yaml

echo "==> 🔑 Contraseña de Argo CD (usuario: admin):"
kubectl get secret argocd-initial-admin-secret \
    -n argocd \
    -o jsonpath='{.data.password}' | base64 -d
echo ""

show_elapsed
echo "==> 🟢 setup.sh completado"
echo "==> GitLab:  kubectl port-forward svc/gitlab-webservice-default -n gitlab 9090:8181"
echo "==> Argo CD: kubectl port-forward svc/argocd-server -n argocd 9443:443"