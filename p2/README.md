# Part 2 — K3s y tres aplicaciones con Ingress

## ¿Qué hemos montado exactamente en la Parte 2?

Partiendo del cluster de la Parte 1, ahora hemos desplegado **3 aplicaciones web reales dentro de Kubernetes** y configurado un sistema de enrutamiento inteligente que decide, según el dominio que pides, a qué aplicación mandarte.

```
Tu navegador / curl
    │
    ▼
davgalleS (192.168.56.110) ← única VM, K3s en modo server
    │
    ▼
Traefik (Ingress Controller)
    ├── Host: app1.com  ──► app-one  (1 pod nginx)
    ├── Host: app2.com  ──► app-two  (3 pods nginx balanceados)
    └── cualquier otro  ──► app-three (1 pod nginx)
```

---

## ¿Para qué sirve cada pieza en la vida real?

### Deployment — el vigilante de tus apps

Un Deployment es una orden que le das a Kubernetes:

> *"Quiero que esta aplicación esté siempre corriendo en X copias. Si una se cae, crea otra inmediatamente."*

En producción real esto es crítico. Si tienes una tienda online y uno de los servidores se cae a las 3 de la mañana, Kubernetes lo detecta en segundos y lanza un reemplazo automáticamente. Sin que nadie tenga que hacer nada.

En nuestra Part 2 tenemos 3 Deployments — uno por aplicación. El de app-two tiene `replicas: 3`, que significa que Kubernetes mantiene 3 copias de esa app corriendo siempre.

### Service — la dirección fija

Los pods tienen un problema: cada vez que se crean o destruyen, cambian de IP. Si el Ingress hablara directamente con los pods, perdería la referencia constantemente.

El Service actúa como intermediario estable:

> *"Yo siempre estoy en la misma dirección. Habla conmigo y yo me encargo de encontrar los pods correctos."*

En producción, el Service también hace **balanceo de carga** automático. Si app-two tiene 3 réplicas, el Service reparte las peticiones entre las tres de forma equitativa. Exactamente lo que hace AWS Elastic Load Balancer, pero gratis y dentro del cluster.

### Ingress — el enrutador de tráfico HTTP

Es la pieza que hace que todo tenga sentido. Sin Ingress, tendrías que exponer cada aplicación en un puerto diferente (`192.168.56.110:8001` para app1, `:8002` para app2...). Con Ingress, todas comparten el puerto 80 y se distinguen por el dominio:

```
http://app1.com  →  puerto 80  →  Ingress decide  →  app-one
http://app2.com  →  puerto 80  →  Ingress decide  →  app-two
http://192.168.56.110  →  puerto 80  →  Ingress  →  app-three (default)
```

En producción real esto es exactamente cómo funcionan empresas como Airbnb o Spotify: un único punto de entrada (load balancer) que distribuye el tráfico entre decenas de microservicios según la URL o el dominio.

### Traefik — el Ingress Controller

Un Ingress por sí solo es solo un archivo de texto con reglas. Alguien tiene que leerlas y aplicarlas. Eso lo hace el **Ingress Controller**.

K3s viene con **Traefik** instalado por defecto. Es el proceso que realmente escucha en el puerto 80, lee las reglas del Ingress y redirige el tráfico. En otros entornos se usa Nginx Ingress Controller o HAProxy. El concepto es el mismo.

### initContainer — preparar el terreno antes de arrancar

Nginx por defecto muestra su página de bienvenida genérica. Necesitábamos que cada app mostrara algo diferente para poder verificar que el enrutamiento funciona.

El problema: no podemos modificar archivos dentro de un contenedor mientras está arrancando. La solución es el **initContainer**: un contenedor auxiliar que se ejecuta antes del principal, escribe el `index.html` personalizado en un volumen compartido, y desaparece. Cuando nginx arranca, ya encuentra el archivo correcto.

En producción, los initContainers se usan para cosas como: esperar a que una base de datos esté lista antes de arrancar la app, descargar configuraciones desde un servidor remoto, o aplicar migraciones de base de datos.

---

## El problema real que esto resuelve

**Ejemplo:** Trabajamos en una empresa con varios equipos, cada uno con su propia aplicación:

- El equipo de usuarios tiene `api.empresa.com`
- El equipo de pagos tiene `pagos.empresa.com`
- El equipo de analytics tiene `stats.empresa.com`

Sin Kubernetes, cada equipo necesitaría su propio servidor con su propia IP. Con Kubernetes + Ingress, todas las aplicaciones corren en el mismo cluster, comparten los mismos recursos y se acceden por dominio. Si una app necesita más potencia, simplemente aumentas sus réplicas. Si otra no tiene tráfico, reduces las suyas. **Eficiencia total.**

---

## ¿Por qué app-two tiene 3 réplicas y no las demás?

El subject lo pide explícitamente para demostrar el concepto de **escalado horizontal**: en vez de comprar un servidor más potente (escalado vertical), lanzas más copias de tu app (escalado horizontal) y repartes la carga entre ellas.

En la vida real, plataformas como Netflix escalan a miles de réplicas durante las horas punta y las reducen de madrugada. Kubernetes hace esto automáticamente con el **Horizontal Pod Autoscaler** (concepto que va más allá de este proyecto).

---

## ¿Qué es `/etc/hosts` y por qué lo modificamos?

Los dominios como `app1.com` normalmente se resuelven a través de servidores DNS de internet. Nosotros no tenemos un dominio real registrado, solo una IP local.

El archivo `/etc/hosts` permite decirle al sistema operativo:

> *"Cuando alguien pida `app1.com`, no preguntes a internet. La IP es `192.168.56.110`."*

Es el DNS más básico que existe. En producción, gestionarías esto con un servidor DNS real o con Route53 de AWS. Para desarrollo local, `/etc/hosts` es la solución estándar.

---

## Resumen en una frase

> Hemos convertido una sola VM en un servidor capaz de alojar múltiples aplicaciones web simultáneamente, enrutando el tráfico de forma inteligente según el dominio — exactamente como funciona cualquier plataforma de microservicios en producción.