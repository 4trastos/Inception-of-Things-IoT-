# Part 3 — K3d y Argo CD (GitOps)

## ¿Qué hemos montado exactamente en la Parte 3?

Hemos dado un salto cualitativo respecto a las partes anteriores. Ya no aplicamos cambios manualmente con `kubectl apply`. Ahora **el repositorio de GitHub es la fuente de verdad** y Argo CD se encarga de que el cluster siempre refleje lo que hay en el repo.

```
Host Ubuntu
    └── VirtualBox
            └── davgalleS (192.168.56.10)
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

### GitOps — El patrón que lo une todo

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

- **`argocd`**: contiene todos los componentes de Argo CD. Es el sistema de control.
- **`dev`**: contiene la aplicación desplegada. Es el entorno de trabajo.

---

## ¿Qué diferencia hay entre K3s (Part 1 y 2) y K3d (Part 3)?

| | K3s | K3d |
|--|-----|-----|
| Corre en | VM o servidor físico | Contenedores Docker |
| Crear cluster | ~5-10 minutos | ~30 segundos |
| Destruir cluster | `vagrant destroy` | `k3d cluster delete` |
| Uso típico | Producción ligera, IoT, edge | Desarrollo local, CI/CD, testing |
| Requiere | VM o servidor | Solo Docker |

---

## Cómo reproducirlo

```bash
cd p3
vagrant up

# Conectarse a la VM
vagrant ssh davgalleS

# Verificar que todo está corriendo
kubectl get nodes
kubectl get pods -n argocd
kubectl get pods -n dev
kubectl get applications -n argocd
```

---

## Demostrar el ciclo GitOps (cambio de versión)

### 1. Verificar el estado inicial

```bash
# Dentro de la VM
kubectl get applications -n argocd
# NAME             SYNC STATUS   HEALTH STATUS
# wil-playground   Synced        Healthy

kubectl get pods -n dev
# NAME                            READY   STATUS    RESTARTS   AGE
# wil-playground-xxx              1/1     Running   0          Xm

# Matar cualquier port-forward anterior y abrir uno limpio
pkill -f "port-forward" 2>/dev/null; sleep 1
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 3
curl http://localhost:9999/
# {"status":"ok", "message": "v1"}
```

### 2. Cambiar la versión en GitHub (desde el host, fuera de la VM)

```bash
# Salir de la VM primero
exit

# Editar el deployment.yaml
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' p3/confs/deployment.yaml

# Verificar el cambio
grep "image:" p3/confs/deployment.yaml
# image: wil42/playground:v2

# Subir el cambio
git add p3/confs/deployment.yaml
git commit -m "update app to v2"
git push
```

> ⚠️ La imagen `wil42/playground` solo tiene las tags **v1** y **v2** en Docker Hub. No uses v3 ni otras.

### 3. Volver a la VM y esperar que Argo CD sincronice

```bash
vagrant ssh davgalleS

# Argo CD sincroniza automáticamente cada ~3 minutos
# Para verificar que detectó el cambio:
kubectl get applications -n argocd
# NAME             SYNC STATUS   HEALTH STATUS
# wil-playground   Synced        Healthy

# Ver el pod actualizándose en tiempo real
kubectl get pods -n dev -w
# Verás el pod viejo terminando y uno nuevo arrancando

 kubectl get application wil-playground -n argocd -o jsonpath='{.status.sync.status}'jsonpath='{.status.sync.status}'
echo ""
kubectl get application wil-playground -n argocd -o jsonpath='{.status.operationState.phase}'
echo ""
Synced
Succeeded
vagrant@davgalleS:~$ kubectl get application wil-playground -n argocd -o jsonpath='{.status.summary.images}'
echo ""
["wil42/playground:v1"]
vagrant@davgalleS:~$ kubectl get pod -n dev -o jsonpath='{.items[0].spec.containers[0].image}'
echo ""
wil42/playground:v1
vagrant@davgalleS:~$ kubectl annotate application wil-playground -n argocd \

argocd app sync wil-playground --force
application.argoproj.io/wil-playground annotated
-bash: argocd: command not found
vagrant@davgalleS:~$ pkill -f "port-forward" 2>/dev/null; sleep 1
[1]+  Terminated              kubectl port-forward svc/wil-playground -n dev 9999:8888
vagrant@davgalleS:~$ kubectl port-forward svc/wil-playground -n dev 9999:8888 &
[1] 29938
vagrant@davgalleS:~$ Forwarding from 127.0.0.1:9999 -> 8888
vagrant@davgalleS:~$ curl http://localhost:9999/
Handling connection for 9999
{"status":"ok", "message": "v2"}v
```

### 4. Verificar la nueva versión

```bash
# Matar el port-forward anterior
pkill -f "port-forward" 2>/dev/null; sleep 1

# Abrir uno nuevo
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 3
curl http://localhost:9999/
# {"status":"ok", "message": "v2"}
```

---

## Solución de problemas frecuentes

### Port-forward falla: "address already in use"

```bash
pkill -f "port-forward" 2>/dev/null
sleep 1
kubectl port-forward svc/wil-playground -n dev 9999:8888 &
sleep 3
curl http://localhost:9999/
```

### El pod está en ImagePullBackOff

La imagen solicitada no existe en Docker Hub. Verifica qué versión tiene el deployment:

```bash
kubectl get pods -n dev -o jsonpath='{.items[*].spec.containers[*].image}'
```

Si aparece una versión incorrecta (ej. v3), corrígela en el repo y haz push:

```bash
# Desde el host
sed -i 's/wil42\/playground:v3/wil42\/playground:v2/g' p3/confs/deployment.yaml
git add p3/confs/deployment.yaml
git commit -m "revert to v2"
git push
```

Argo CD lo detectará y revertirá el cluster automáticamente en ~3 minutos.

### Ver logs de Argo CD para depurar

```bash
kubectl logs -n argocd deployment/argocd-application-controller --tail=50
```

### Forzar sync sin CLI de Argo CD

```bash
kubectl patch application wil-playground -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

---

## Resultado esperado

```
$ kubectl get ns
NAME              STATUS
argocd            Active
dev               Active
kube-system       Active

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