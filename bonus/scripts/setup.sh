#!/bin/bash
set -e
export KUBECONFIG=/home/vagrant/.kube/config

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
    --timeout 1200s \
    --set global.hosts.domain=192.168.56.10.nip.io \
    --set global.hosts.externalIP=192.168.56.10 \
    --set global.hosts.https=false \
    --set global.edition=ce \
    --set certmanager-issuer.email=admin@gitlab.local \
    --set global.ingress.configureCertmanager=false \
    --set global.ingress.tls.enabled=false \
    --set global.ingress.class=traefik \
    --set global.ingress.provider=traefik \
    --set nginx-ingress.enabled=false \
    --set gitlab-runner.install=false \
    --set prometheus.install=false \
    --set grafana.enabled=false \
    --set global.kas.enabled=false \
    --set gitlab.gitlab-shell.enabled=false \
    --set gitlab.webservice.minReplicas=1 \
    --set gitlab.webservice.maxReplicas=1 \
    --set gitlab.sidekiq.minReplicas=1 \
    --set gitlab.sidekiq.maxReplicas=1 \
    --set redis.master.persistence.enabled=false \
    --set postgresql.primary.persistence.enabled=false \
    --set minio.persistence.enabled=false
show_elapsed

echo "==> ⚠️ Esperando a que GitLab arranque (puede tardar 15 min)..."
TIMEOUT=1200
ELAPSED_WAIT=0
until kubectl get pod -l app=webservice -n gitlab \
    -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
    2>/dev/null | grep -q "True"; do
    if [ $ELAPSED_WAIT -ge $TIMEOUT ]; then
        echo "ERROR: Timeout esperando webservice"
        kubectl describe pod -l app=webservice -n gitlab
        exit 1
    fi
    STATUS=$(kubectl get pod -l app=webservice -n gitlab \
        --no-headers 2>/dev/null | awk '{print $2,$3}' | head -1)
    echo "  ... $(date '+%H:%M:%S') webservice => ${STATUS:-pending}"
    sleep 20
    ELAPSED_WAIT=$((ELAPSED_WAIT + 20))
done
show_elapsed

echo "==> ⚙️ Creando repositorio iot-manifests en GitLab..."
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab \
    -o jsonpath='{.data.password}' | base64 -d)

echo "==> 🔑 Contraseña de GitLab (usuario: root): $GITLAB_PASS"

# Obtener token OAuth
GITLAB_TOKEN=$(curl -sf --request POST \
    "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/oauth/token" \
    --data "grant_type=password&username=root&password=${GITLAB_PASS}" \
    | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "==> ⚙️ Token obtenido, creando proyecto..."

# Crear el proyecto iot-manifests
curl -sf --request POST \
    "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/api/v4/projects" \
    --header "Authorization: Bearer $GITLAB_TOKEN" \
    --header "Content-Type: application/json" \
    --data '{"name": "iot-manifests", "visibility": "public", "initialize_with_readme": false}'

echo ""
echo "==> ⚙️ Subiendo deployment.yaml al repositorio..."
sleep 5

curl -sf --request POST \
    "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/api/v4/projects/1/repository/files/manifests%2Fdeployment.yaml" \
    --header "Authorization: Bearer $GITLAB_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{
        \"branch\": \"main\",
        \"content\": \"$(cat /vagrant/confs/deployment.yaml | sed 's/\\/\\\\/g' | sed 's/\"/\\\"/g' | sed ':a;N;\$!ba;s/\n/\\n/g')\",
        \"commit_message\": \"Add wil-playground deployment\"
    }"

echo ""
echo "==> 🟢 Repositorio iot-manifests creado y deployment.yaml subido"

echo "==> ⚠️ Esperando a que Argo CD arranque..."
wait $ARGOCD_PID
kubectl wait --for=condition=Ready pods --all \
    -n argocd \
    --timeout=300s
show_elapsed

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