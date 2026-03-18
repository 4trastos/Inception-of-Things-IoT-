# 🚀 Inception-of-Things (IoT)

> Proyecto de administración de sistemas de la escuela 42 — Kubernetes con K3s, K3d, Vagrant y Argo CD.

---

## 📋 Índice

- [¿Qué es este proyecto?](#-qué-es-este-proyecto)
- [Tecnologías utilizadas](#-tecnologías-utilizadas)
- [Estructura del repositorio](#-estructura-del-repositorio)
- [Part 1 — K3s y Vagrant](#-part-1--k3s-y-vagrant)
- [Part 2 — K3s y tres aplicaciones](#-part-2--k3s-y-tres-aplicaciones)
- [Part 3 — K3d y Argo CD](#-part-3--k3d-y-argo-cd)
- [Bonus — GitLab local](#-bonus--gitlab-local) *(pendiente)*

---

## 🧠 ¿Qué es este proyecto?

**Inception-of-Things** es una introducción práctica a Kubernetes. El objetivo es configurar entornos progresivamente más complejos, aprendiendo a usar:

- **Vagrant** para gestionar máquinas virtuales como código
- **K3s** como distribución ligera de Kubernetes
- **K3d** para correr K3s dentro de Docker
- **Argo CD** para implementar el patrón GitOps (CI/CD declarativo)

---

## 🛠️ Tecnologías utilizadas

| Herramienta | Versión | Uso |
|-------------|---------|-----|
| Vagrant | 2.4.9 | Gestión de VMs |
| VirtualBox | 7.2.2 | Hypervisor |
| K3s | v1.34.5+k3s1 | Kubernetes ligero |
| K3d | latest | K3s en Docker |
| Debian | bookworm64 | SO de las VMs |
| kubectl | latest | CLI de Kubernetes |

---

## 📁 Estructura del repositorio

```
.
├── p1/                          # Part 1: K3s con Vagrant (2 VMs)
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── server.sh            # Provisión del nodo controller
│   │   └── worker.sh            # Provisión del nodo agent
│   └── confs/
├── p2/                          # Part 2: K3s con 3 apps e Ingress
│   ├── Vagrantfile
│   ├── scripts/
│   │   └── server.sh            # Provisión del server + apply de manifiestos
│   └── confs/
│       ├── apps.yaml            # Deployments y Services de las 3 apps
│       ├── ingress.yaml         # Reglas de enrutamiento por hostname
│       └── ingress-default.yaml # Ingress catch-all para app3
├── p3/                          # Part 3: K3d + Argo CD
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── install.sh           # Instala Docker, K3d y kubectl en la VM
│   │   └── setup.sh             # Crea el cluster, instala Argo CD y despliega la app
│   └── confs/
│       ├── deployment.yaml      # Deployment + Service de wil-playground (app a desplegar)
│       └── argocd-app.yaml      # Application de Argo CD apuntando al repo de GitHub
├── bonus/                       # Bonus: GitLab local
│   ├── scripts/
│   └── confs/
└── README.md
```

---

## ✅ Part 1 — K3s y Vagrant

### ¿Qué hace esta parte?

Crea un cluster Kubernetes de 2 nodos usando Vagrant + VirtualBox:

| VM | Hostname | IP | Rol en K3s |
|----|----------|----|------------|
| Máquina 1 | `davgalleS` | `192.168.56.110` | **Server** (control-plane) |
| Máquina 2 | `davgalleSW` | `192.168.56.111` | **Worker** (agent) |

### Conceptos aprendidos

- **Vagrant**: define infraestructura como código en un `Vagrantfile`. Con `vagrant up` levanta las VMs automáticamente.
- **K3s server**: nodo que gestiona el cluster (control-plane). Genera el token que necesitan los workers para unirse.
- **K3s agent**: nodo worker que ejecuta los pods. Se une al cluster usando el token del server.
- **Carpeta compartida `/vagrant/`**: Vagrant monta automáticamente la carpeta del proyecto dentro de cada VM, lo que permite pasar el token del server al worker sin configuración extra.

### Cómo funciona el flujo de provisión

```
vagrant up
    │
    ├─► Crea davgalleS (192.168.56.110)
    │       └─► Ejecuta server.sh
    │               ├─► Instala curl
    │               ├─► Instala K3s en modo server
    │               ├─► Guarda node-token en /vagrant/scripts/
    │               └─► Configura kubectl sin sudo
    │
    └─► Crea davgalleSW (192.168.56.111)
            └─► Ejecuta worker.sh
                    ├─► Espera a que exista node-token
                    ├─► Lee el token
                    └─► Instala K3s en modo agent (se une al cluster)
```

### Cómo reproducirlo

**Requisitos:** VirtualBox y Vagrant instalados.

```bash
# Instalar Vagrant desde HashiCorp (no desde apt)
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant virtualbox

# Levantar el cluster
cd p1
vagrant up

# Conectarse al server y verificar
vagrant ssh davgalleS
kubectl get nodes -o wide
```

### Resultado esperado

```
NAME         STATUS   ROLES           AGE   VERSION        INTERNAL-IP
davgalles    Ready    control-plane   Xm    v1.34.5+k3s1   192.168.56.110
davgallesw   Ready    <none>          Xm    v1.34.5+k3s1   192.168.56.111
```

### Comandos útiles

```bash
vagrant status              # Ver estado de las VMs
vagrant ssh davgalleS       # Conectar al server
vagrant ssh davgalleSW      # Conectar al worker
vagrant halt                # Apagar las VMs
vagrant destroy -f          # Eliminar las VMs
vagrant up                  # Volver a crear las VMs
```

---

## 🔄 Part 2 — K3s y tres aplicaciones

### ¿Qué hace esta parte?

Una sola VM con K3s en modo server que ejecuta 3 aplicaciones web. El tráfico se enruta a cada app según el header `Host` de la petición HTTP, usando el Ingress Controller **Traefik** que viene incluido en K3s.

| App | Host | Réplicas | Respuesta |
|-----|------|----------|-----------|
| app-one | `app1.com` | 1 | Hello from app1 |
| app-two | `app2.com` | **3** | Hello from app2 |
| app-three | cualquier otro | 1 | Hello from app3 |

### Conceptos aprendidos

- **Deployment**: garantiza que N réplicas de un pod estén siempre corriendo. Si un pod muere, K8s lo recrea automáticamente.
- **Service**: da una IP/DNS interna estable para acceder a los pods de un Deployment. El Ingress se comunica con los Services, no con los pods directamente.
- **Ingress**: reglas de enrutamiento HTTP. Examina el header `Host` de cada petición y la redirige al Service correcto.
- **initContainer**: contenedor que se ejecuta antes del contenedor principal para preparar el entorno. En este caso escribe el `index.html` personalizado antes de que nginx arranque.
- **Labels y Selectors**: mecanismo que conecta Deployments con Services. El Deployment crea pods con una etiqueta (`app: app-one`) y el Service busca pods con esa misma etiqueta.

### Arquitectura del enrutamiento

```
Petición HTTP (Host: app2.com)
    │
    ▼
Ingress (Traefik — 192.168.56.110:80)
    │  Regla: Host app2.com → Service app-two
    ▼
Service app-two (ClusterIP)
    │  Balancea entre 3 réplicas automáticamente
    ├──► Pod app-two-1
    ├──► Pod app-two-2
    └──► Pod app-two-3
```

### Cómo reproducirlo

```bash
cd p2
vagrant up

# Verificar que los 5 pods están corriendo (1+3+1)
vagrant ssh davgalleS
kubectl get pods
kubectl get ingress
```

### Añadir los hosts en tu máquina (para acceso desde el navegador)

```bash
# En tu PC host (no en la VM)
echo "192.168.56.110 app1.com" | sudo tee -a /etc/hosts
echo "192.168.56.110 app2.com" | sudo tee -a /etc/hosts
echo "192.168.56.110 app3.com" | sudo tee -a /etc/hosts
```

### Verificar el enrutamiento

```bash
# Desde tu PC host
curl -H "Host: app1.com" http://192.168.56.110   # → Hello from app1
curl -H "Host: app2.com" http://192.168.56.110   # → Hello from app2
curl http://192.168.56.110                        # → Hello from app3 (default)

# O desde el navegador:
# http://app1.com  → app1
# http://app2.com  → app2
# http://192.168.56.110 → app3
```

### Resultado esperado

```
NAME                         READY   STATUS    RESTARTS   AGE
app-one-xxx                  1/1     Running   0          5m
app-three-xxx                1/1     Running   0          5m
app-two-xxx                  1/1     Running   0          5m  ← réplica 1
app-two-xxx                  1/1     Running   0          5m  ← réplica 2
app-two-xxx                  1/1     Running   0          5m  ← réplica 3

NAME                   CLASS     HOSTS                        ADDRESS          PORTS
apps-ingress           <none>    app1.com,app2.com,app3.com   192.168.56.110   80
apps-ingress-default   traefik   *                            192.168.56.110   80
```

---

## ⚙️ Part 3 — K3d y Argo CD

### ¿Qué hace esta parte?

Una VM con Docker que ejecuta un cluster K3d (K3s dentro de Docker). Argo CD vigila este repositorio de GitHub y despliega automáticamente la aplicación `wil42/playground` en el namespace `dev`. Cualquier cambio en el repo se refleja en el cluster sin intervención manual.

| Namespace | Contenido |
|-----------|-----------|
| `argocd` | Argo CD — el sistema que vigila GitHub y sincroniza el cluster |
| `dev` | `wil-playground` — la app desplegada automáticamente por Argo CD |

### Conceptos aprendidos

- **K3d**: herramienta que ejecuta K3s dentro de contenedores Docker. Crear un cluster tarda 30 segundos en lugar de minutos.
- **GitOps**: patrón donde Git es la única fuente de verdad. El estado del cluster siempre refleja lo que hay en el repositorio.
- **Argo CD**: herramienta GitOps que vigila un repo de GitHub y sincroniza automáticamente los cambios al cluster.
- **Namespaces**: aislamiento lógico dentro del cluster. Cada namespace tiene sus propios recursos independientes.

### Arquitectura GitOps

```
git push (cambio de v1 a v2)
    │
    ▼
GitHub (4trastos/Inception-of-Things-IoT-)
    │  Argo CD detecta el cambio cada ~3 minutos
    ▼
Argo CD (namespace: argocd)
    │  Compara repo vs cluster → detecta diferencia
    │  Aplica el nuevo deployment automáticamente
    ▼
namespace: dev
    └── wil-playground pod actualizado a v2 ✅
```

### Cómo reproducirlo

```bash
cd p3
vagrant up

# Conectarse y verificar
vagrant ssh davgalleS
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n dev
kubectl get applications -n argocd
```

### Demostrar el ciclo GitOps (obligatorio en la evaluación)

```bash
# 1. Verificar que la app está en v1
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 2
curl http://localhost:9999/
# {"status":"ok", "message": "v1"}

# 2. Salir de la VM y cambiar la versión en GitHub
exit
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' p3/confs/deployment.yaml
git add p3/confs/deployment.yaml
git commit -m "update app to v2"
git push

# 3. Volver a la VM y esperar ~3 minutos a que Argo CD sincronice
vagrant ssh davgalleS
kubectl get applications -n argocd   # Synced + Healthy
kubectl get pods -n dev              # Pod nuevo arrancando

# 4. Verificar la nueva versión
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 2
curl http://localhost:9999/
# {"status":"ok", "message": "v2"}
```

### Resultado esperado

```
$ kubectl get namespaces
NAME              STATUS
argocd            Active
dev               Active
...

$ kubectl get pods -n dev
NAME                              READY   STATUS    RESTARTS   AGE
wil-playground-xxx                1/1     Running   0          Xm

$ kubectl get applications -n argocd
NAME             SYNC STATUS   HEALTH STATUS
wil-playground   Synced        Healthy
```

---

## 🦊 Bonus — GitLab local

> *Pendiente...*

Instancia de GitLab corriendo localmente en el cluster (namespace `gitlab`), integrada con Argo CD como sustituto de GitHub.

---

## 👤 Autor

**davgalle** y **nicgonza** — Estudiantes de 42
