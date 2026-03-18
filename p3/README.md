# Part 3 — K3d y Argo CD (GitOps)

## ¿Qué hemos montado exactamente en la Parte 3?

Hemos dado un salto cualitativo respecto a las partes anteriores. Ya no aplicamos cambios manualmente con `kubectl apply`. Ahora **el repositorio de GitHub es la fuente de verdad** y Argo CD se encarga de que el cluster siempre refleje lo que hay en el repo.

```
Tu portátil Ubuntu
    └── VirtualBox
            └── davgalleS (192.168.56.110)
                    └── Docker
                            └── K3d (cluster Kubernetes dentro de Docker)
                                    ├── namespace: argocd  ← Argo CD vigilando GitHub
                                    └── namespace: dev     ← App desplegada automáticamente
```

---

## ¿Para qué sirve cada pieza en la vida real?

### K3d — Kubernetes dentro de Docker

En las partes anteriores K3s corría directamente en una VM. K3d va un paso más allá: **mete K3s dentro de contenedores Docker**.

¿Por qué es útil? Porque crear y destruir un cluster K3d tarda 30 segundos, frente a los 5-10 minutos de una VM. En empresas reales, los equipos de DevOps crean clusters efímeros para cada pipeline de CI/CD, los usan para ejecutar los tests y los destruyen inmediatamente. Con K3d esto es trivial.

```bash
k3d cluster create mi-cluster   # 30 segundos
k3d cluster delete mi-cluster   # 5 segundos
```

### Argo CD — El guardián de tu infraestructura

Argo CD implementa el patrón **GitOps**. La idea es simple pero poderosa:

> *"El estado de tu cluster debe ser exactamente lo que describes en Git. Siempre."*

Argo CD vigila tu repositorio de GitHub cada pocos minutos. Si detecta que el cluster no coincide con lo que hay en el repo, lo corrige automáticamente. Esto tiene varias ventajas enormes en producción:

- **Trazabilidad total**: cada cambio en el cluster queda registrado en Git con autor, fecha y mensaje
- **Rollback instantáneo**: si algo falla, haces `git revert` y Argo CD revierte el cluster automáticamente
- **Sin acceso directo al cluster**: los desarrolladores nunca tocan el cluster directamente, solo hacen push a Git
- **Auditoría**: cualquier persona puede ver la historia completa de cambios

En empresas como Spotify, Intuit o Red Hat, Argo CD gestiona clusters con miles de microservicios.

### GitOps — El patrón que lo une todo

GitOps es una forma de trabajar, no una herramienta. Define que:

1. **Git es la única fuente de verdad** — si no está en Git, no existe
2. **Los cambios se hacen via Pull Requests** — revisión de código para infraestructura
3. **El despliegue es automático** — nadie ejecuta comandos manualmente en producción
4. **El sistema se auto-corrige** — si alguien toca el cluster a mano, Argo CD lo revierte

```
Desarrollador
    │  git push
    ▼
GitHub (repo público)
    │  Argo CD detecta el cambio (cada 3 min)
    ▼
Argo CD compara repo vs cluster
    │  "El cluster tiene v1 pero el repo dice v2"
    ▼
Argo CD aplica el cambio automáticamente
    │
    ▼
Pod actualizado a v2 ✅
```

### Los dos namespaces

Kubernetes usa **namespaces** para aislar recursos dentro del mismo cluster. Es como tener carpetas dentro de un disco duro — los recursos de una carpeta no interfieren con los de otra.

- **`argocd`**: contiene todos los componentes de Argo CD (7 pods). Es el sistema de control.
- **`dev`**: contiene la aplicación desplegada. Es el entorno de trabajo.

En producción real habría namespaces como `staging`, `production`, `monitoring`, `logging`... cada uno con sus propios recursos y permisos.

---

## El problema real que esto resuelve

**Sin GitOps** — situación típica en empresas sin buenas prácticas:

> *Alguien ejecuta `kubectl apply` en producción a las 2 de la mañana para arreglar un bug urgente. Nadie sabe qué cambió exactamente. Al día siguiente nadie recuerda qué se hizo. El cluster está en un estado desconocido.*

**Con GitOps** — lo que hemos montado:

> *Todo cambio pasa por Git. Si algo falla, `git revert` y en 3 minutos el cluster vuelve al estado anterior. El historial de Git es el historial completo de tu infraestructura.*

---

## ¿Qué diferencia hay entre K3s (Part 1 y 2) y K3d (Part 3)?

| | K3s | K3d |
|--|-----|-----|
| Corre en | VM o servidor físico | Contenedores Docker |
| Crear cluster | ~5-10 minutos | ~30 segundos |
| Destruir cluster | `vagrant destroy` | `k3d cluster delete` |
| Uso típico | Producción ligera, IoT, edge | Desarrollo local, CI/CD, testing |
| Requiere | VM o servidor | Solo Docker |

K3d no reemplaza a K3s — los usa conjuntamente. K3d es la herramienta, K3s es el motor que corre dentro.

---

## Cómo reproducirlo

```bash
cd p3
vagrant up

# Verificar que todo está corriendo
vagrant ssh davgalleS
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n dev
kubectl get applications -n argocd
```

### Demostrar el ciclo GitOps (cambio de versión)

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

# 3. Volver a la VM y esperar ~3 minutos
vagrant ssh davgalleS
kubectl get applications -n argocd   # Synced + Healthy
kubectl get pods -n dev              # Pod nuevo arrancando

# 4. Verificar la nueva versión
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 2
curl http://localhost:9999/
# {"status":"ok", "message": "v2"}
```

---

## Resultado esperado

```
$ kubectl get ns
NAME              STATUS
argocd            Active
dev               Active
kube-system       Active
...

$ kubectl get pods -n dev
NAME                              READY   STATUS    RESTARTS   AGE
wil-playground-xxx                1/1     Running   0          Xm

$ kubectl get applications -n argocd
NAME             SYNC STATUS   HEALTH STATUS
wil-playground   Synced        Healthy
```

---

## Resumen en una frase

> Hemos implementado un sistema GitOps completo donde un push a GitHub es suficiente para actualizar automáticamente una aplicación en producción — exactamente como trabajan los equipos de DevOps en empresas tecnológicas reales.