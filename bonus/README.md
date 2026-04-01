# Bonus — GitLab local integrado con Argo CD

## ¿Qué hemos montado exactamente en el Bonus?

Hemos reemplazado GitHub por una instancia **local de GitLab** corriendo dentro del mismo cluster K3d. Todo el flujo GitOps de la Part 3 funciona igual, pero ahora la fuente de verdad es un GitLab que vive dentro de nuestra infraestructura, sin depender de internet.

```
Tu portátil
    └── VirtualBox
            └── davgalleS (192.168.56.10)
                    └── Docker
                            └── K3d cluster
                                    ├── namespace: gitlab   ← GitLab CE (fuente de verdad)
                                    ├── namespace: argocd   ← Argo CD (vigila GitLab)
                                    └── namespace: dev      ← wil-playground (desplegado automáticamente)
```

El flujo GitOps ahora es 100% local:

```
Tú haces push a GitLab local
    │
    ▼
GitLab (namespace: gitlab, dentro del cluster)
    │  Argo CD detecta el cambio cada ~3 minutos
    ▼
Argo CD (namespace: argocd)
    │  Sincroniza automáticamente
    ▼
namespace: dev
    └── wil-playground actualizado ✅
```

---

## ¿Para qué sirve GitLab en la vida real?

GitLab es una plataforma completa de DevOps que incluye repositorio Git, CI/CD, registro de contenedores, gestión de issues y mucho más. Empresas que no quieren depender de servicios externos (GitHub, Bitbucket) instalan GitLab en sus propios servidores — exactamente lo que hemos hecho aquí.

La diferencia clave con la Part 3:

| | Part 3 | Bonus |
|--|--------|-------|
| Repositorio | GitHub (externo, internet) | GitLab (local, dentro del cluster) |
| Dependencia de red | Sí | No |
| Control total | No | Sí |
| Complejidad | Baja | Alta |

En empresas con datos sensibles (banca, salud, defensa), tener el repositorio fuera de sus servidores no es una opción. GitLab self-hosted es la solución estándar.

---

## Arquitectura técnica

El bonus usa **GitLab CE instalado con Helm** dentro del namespace `gitlab`. Helm es un gestor de paquetes para Kubernetes — piensa en él como el `apt` de Kubernetes.

```
Helm chart de GitLab CE
    └── namespace: gitlab
            ├── gitlab-webservice    ← La interfaz web y API de GitLab
            ├── gitlab-gitaly        ← Almacenamiento de repositorios Git
            ├── gitlab-postgresql    ← Base de datos
            ├── gitlab-redis         ← Cache y colas
            ├── gitlab-sidekiq       ← Procesamiento de tareas en background
            ├── gitlab-registry      ← Registro de imágenes Docker
            └── gitlab-minio         ← Almacenamiento de objetos (artefactos, backups)
```

Argo CD se conecta a GitLab usando la URL interna del cluster:
```
http://gitlab-webservice-default.gitlab.svc.cluster.local:8181
```

Esto significa que la comunicación entre Argo CD y GitLab nunca sale del cluster — es completamente interna.

---

## Setup automatizado

El bonus está completamente automatizado. El script `setup.sh` hace todo:

1. Crea el cluster K3d
2. Instala GitLab con Helm y Argo CD en paralelo
3. Espera a que GitLab arranque completamente
4. Crea automáticamente el repositorio `iot-manifests` via API de GitLab
5. Sube el `deployment.yaml` al repositorio
6. Configura Argo CD para vigilar GitLab
7. Muestra las contraseñas generadas

---

## Cómo reproducirlo

```bash
cd bonus
vagrant up

# El setup corre en background, seguir el progreso con:
vagrant ssh davgalleS
tail -f /var/log/iot-setup.log
```

### Verificar que todo está corriendo

```bash
kubectl get namespaces
kubectl get pods -n gitlab
kubectl get pods -n argocd
kubectl get pods -n dev
kubectl get applications -n argocd
```

### Acceder a GitLab

```bash
# Port-forward para acceder desde el navegador
kubectl port-forward svc/gitlab-webservice-default -n gitlab 9090:8181 --address 0.0.0.0 &

# Obtener la contraseña de root
kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab \
    -o jsonpath='{.data.password}' | base64 -d
```

Abre `http://192.168.56.10:9090` en el navegador — usuario `root`, contraseña la del comando anterior.

### Demostrar el ciclo GitOps con GitLab local

```bash
# 1. Verificar que la app está en v1
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 2
curl http://localhost:9999/
# {"status":"ok", "message": "v1"}

# 2. Obtener token de GitLab
GITLAB_PASS=$(kubectl get secret gitlab-gitlab-initial-root-password \
    -n gitlab -o jsonpath='{.data.password}' | base64 -d)

GITLAB_TOKEN=$(curl -sf --request POST \
    "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/oauth/token" \
    --data "grant_type=password&username=root&password=${GITLAB_PASS}" \
    | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# 3. Cambiar v1 por v2 en GitLab via API
CONTENT=$(cat /vagrant/confs/deployment.yaml | \
    sed 's/playground:v1/playground:v2/' | \
    sed 's/\\/\\\\/g' | sed 's/\"/\\\"/g' | \
    sed ':a;N;$!ba;s/\n/\\n/g')

curl -sf --request PUT \
    "http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/api/v4/projects/1/repository/files/manifests%2Fdeployment.yaml" \
    --header "Authorization: Bearer $GITLAB_TOKEN" \
    --header "Content-Type: application/json" \
    --data "{\"branch\":\"main\",\"content\":\"${CONTENT}\",\"commit_message\":\"Update app to v2\"}"

# 4. Esperar ~3 minutos y verificar
sleep 180
curl http://localhost:9999/
# {"status":"ok", "message": "v2"}
```

---

## Resultado esperado

```
$ kubectl get namespaces
NAME              STATUS
argocd            Active
dev               Active
gitlab            Active
...

$ kubectl get pods -n gitlab
gitlab-webservice-default-xxx   2/2   Running   0   Xm
gitlab-postgresql-0             2/2   Running   0   Xm
gitlab-redis-master-0           2/2   Running   0   Xm
... (todos en Running)

$ kubectl get pods -n dev
NAME                              READY   STATUS    RESTARTS   AGE
wil-playground-xxx                1/1     Running   0          Xm

$ kubectl get applications -n argocd
NAME             SYNC STATUS   HEALTH STATUS
wil-playground   Synced        Healthy

$ curl http://localhost:9999/
{"status":"ok", "message": "v1"}
```

---

## Notas importantes para la evaluación

- El setup tarda **~10 minutos** — GitLab CE es una aplicación grande con muchos componentes
- La VM necesita **8GB de RAM y 4 CPUs** para que GitLab funcione correctamente
- En el campus de 42, asegúrate de clonar el repo en `/goinfre` y configurar `VAGRANT_HOME` ahí
- La contraseña de GitLab es aleatoria y se genera en cada instalación — siempre obtenerla con el comando del Secret

---

## Resumen en una frase

> Hemos llevado el GitOps al siguiente nivel: toda la infraestructura, incluyendo el repositorio Git, corre dentro de nuestro propio cluster Kubernetes — sin depender de ningún servicio externo.