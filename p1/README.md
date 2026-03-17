## ¿Qué hemos montado exactamente en la Parte 1?

Hemos creado **un cluster de Kubernetes real**. Dos máquinas virtuales que se hablan entre ellas y forman un sistema capaz de gestionar contenedores de forma automática.

```
Tu portátil Ubuntu
    └── VirtualBox
            ├── davgalleS  (192.168.56.110)  ← El "jefe"
            └── davgalleSW (192.168.56.111)  ← El "trabajador"
```

---

## ¿Para qué sirve cada pieza en la vida real?

### Vagrant
En la realidad, cuando una empresa quiere que todos sus desarrolladores tengan el mismo entorno, usan herramientas como Vagrant. En vez de decirle a cada uno "instala esto, configura aquello", les das un `Vagrantfile` y con `vagrant up` todos tienen exactamente la misma máquina. **Infraestructura como código.**

### K3s server (davgalleS)
Es el **cerebro del cluster**. En producción real (Amazon, Google, empresas grandes) esto sería un nodo maestro de Kubernetes gestionando cientos de workers. Su trabajo es:
- Decidir en qué máquina se ejecuta cada contenedor
- Vigilar que todo esté corriendo
- Reiniciar cosas que fallen automáticamente

### K3s worker (davgalleSW)
Es el **músculo**. Solo ejecuta lo que el server le ordena. En producción habría decenas o cientos de workers. Si uno se cae, el server mueve su trabajo a otro. Nadie se entera nunca.

---

## El problema real que esto resuelve

**Ejemplo:** Trabajaramos en Netflix y tenemos una aplicación que recibe millones de peticiones. Necesitamos:

- Si un servidor se rompe, la app siga funcionando → **K8s lo hace solo**
- Si hay mucho tráfico, se lancen más copias de la app → **K8s lo hace solo**
- Que al actualizar la app no cause caídas → **K8s lo hace solo**

Todo eso lo gestiona Kubernetes. Lo que hemos montado es exactamente eso, pero en pequeño.

---

## ¿Por qué K3s y no Kubernetes normal?

Kubernetes completo necesita varios GB de RAM solo para arrancar. **K3s** es una versión simplificada pensada para:
- Entornos con pocos recursos (Raspberry Pi, VMs pequeñas)
- Aprender sin necesitar un servidor potente
- Edge computing (fábricas, coches, dispositivos IoT)

Por eso el proyecto se llama **Inception-of-Things** — IoT no es solo "Internet of Things", es un guiño a que K3s se usa mucho en dispositivos pequeños.

---

## Resumen en una frase

> Hemos automatizado la creación de un cluster Kubernetes de 2 nodos con código, exactamente como se hace en empresas reales, solo que en miniatura.
