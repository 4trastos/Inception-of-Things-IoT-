# 🚀 Inception-of-Things (IoT)

> Proyecto de administración de sistemas de la escuela 42 — Kubernetes con K3s, K3d, Vagrant y Argo CD.

---

## 📋 Índice

- [¿Qué es este proyecto?](#-qué-es-este-proyecto)
- [Tecnologías utilizadas](#-tecnologías-utilizadas)
- [Estructura del repositorio](#-estructura-del-repositorio)
- [Part 1 — K3s y Vagrant](#-part-1--k3s-y-vagrant)
- [Part 2 — K3s y tres aplicaciones](#-part-2--k3s-y-tres-aplicaciones) *(en progreso)*
- [Part 3 — K3d y Argo CD](#-part-3--k3d-y-argo-cd) *(pendiente)*
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
├── p1/                     # Part 1: K3s con Vagrant (2 VMs)
│   ├── Vagrantfile
│   ├── scripts/
│   │   ├── server.sh       # Provisión del nodo controller
│   │   └── worker.sh       # Provisión del nodo agent
│   └── confs/
├── p2/                     # Part 2: K3s con 3 apps e Ingress
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
├── p3/                     # Part 3: K3d + Argo CD
│   ├── scripts/
│   └── confs/
├── bonus/                  # Bonus: GitLab local
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

> *En progreso...*

Una sola VM con K3s en modo server. Tres aplicaciones web con enrutamiento por `Host` header mediante Ingress (Traefik).

---

## ⚙️ Part 3 — K3d y Argo CD

> *Pendiente...*

Cluster K3d (K3s en Docker) con Argo CD implementando GitOps: los cambios en este repositorio se sincronizan automáticamente al cluster.

---

## 🦊 Bonus — GitLab local

> *Pendiente...*

Instancia de GitLab corriendo localmente en el cluster (namespace `gitlab`), integrada con Argo CD como sustituto de GitHub.

---

## 👤 Autor

**davgalle** y **nicgonza** — Estudiantes de 42
