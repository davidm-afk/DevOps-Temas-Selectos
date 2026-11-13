# Reporte de Práctica: Namespaces, Pods, ConfigMaps, Secrets, RBAC y Deployments en Kubernetes

**Materia:** DevOps  
**Estudiante:** Aldo Aaron Gonzalez Chavez  
**Fecha:** 6 de Noviembre de 2026  
**Entorno de Ejecución:** Clúster Kubernetes v1.31.14 (Master: `192.168.56.102` | Worker: `192.168.56.101`)  
**Laboratorios Desarrollados:** 
* Lab 01 (Namespace y Aislamiento)
* Lab 02 (Pod Básico, Patrón Sidecar y Patrón Init Container)
* Lab 03 (ConfigMap y Hot Reload)
* Lab 04 (Secrets y Decodificación Base64)
* Lab 05 (ServiceAccount y Auditoría RBAC con `can-i`)
* Lab 06 (Deployment, Escalado Elástico, Rolling Updates y Rollback)

---

## 1. Objetivos de la Práctica

* Comprender e implementar el aislamiento lógico de recursos dentro del clúster mediante **Namespaces**.
* Configurar el contexto de administración de `kubectl` para fijar un espacio de trabajo por defecto.
* Desplegar la unidad mínima de cómputo en Kubernetes (**Pod**) de forma declarativa mediante manifiestos YAML.
* Analizar la programación y calendarización de Pods en el nodo de cómputo (**Worker**) a través del kube-scheduler.
* Implementar el **Patrón Sidecar** con múltiples contenedores compartiendo un volumen común (`emptyDir`) y red local (`localhost`).
* Implementar el **Patrón Init Container** para la secuenciación de dependencias previas al arranque del contenedor principal.
* Administrar configuraciones desacopladas del código mediante **ConfigMaps** bajo los principios de *12-Factor App*, comprobando el mecanismo de **Hot Reload** en caliente.
* Gestionar información sensible y credenciales mediante el objeto **Secret**, analizando el esquema de codificación en Base64 frente a soluciones de cifrado real y su consumo en variables de entorno.
* Configurar identidades de aplicación seguras mediante **ServiceAccount** y políticas de control de acceso basadas en roles (**RBAC**), validando privilegios con `kubectl auth can-i`.
* Desplegar y administrar aplicaciones sin estado con **Deployments**, ejecutando operaciones de escalabilidad elástica, actualizaciones progresivas (*Rolling Updates*) y reversión inmediata (*Rollback*) ante fallos de despliegue.
* Inspeccionar el ciclo de vida, registros de eventos (`events`), logs de contenedores específicos y verificar la conectividad mediante reenvío de puertos (`port-forward`).

---

## 2. Preparación y Verificación del Clúster

Antes de iniciar el despliegue de los laboratorios, se verificó el estado operativo de los nodos que conforman el clúster:

```bash
[root@k8s-master ~]# kubectl get nodes
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   11h   v1.31.14
k8s-worker1   Ready    <none>          11h   v1.31.14
```

Ambos nodos respondieron en estado `Ready`, confirmando la persistencia y disponibilidad de la infraestructura configurada previamente.

---

## 3. Lab 01: Gestión y Aislamiento con Namespaces

Un **Namespace** permite segmentar un único clúster físico en múltiples entornos virtuales aislados, facilitando el control de acceso, cuotas de recursos y delimitación por proyectos (e.g., `dev`, `staging`, `prod`).

### 3.1 Creación Declarativa del Namespace `bootcamp`
Se utilizó el manifiesto `/root/kubernetes/01-namespace/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bootcamp
  labels:
    env: training
    team: devops
```

Comando ejecutado en la terminal del Master:
```bash
[root@k8s-master 01-namespace]# kubectl apply -f namespace.yaml
namespace/bootcamp created
```

### 3.2 Creación Imperativa de Entornos Adicionales
Para comprobar los distintos métodos de aprovisionamiento en Kubernetes, se generaron los namespaces de desarrollo y producción mediante comandos directos de CLI:

```bash
[root@k8s-master 01-namespace]# kubectl create namespace dev
namespace/dev created

[root@k8s-master 01-namespace]# kubectl create namespace prod
namespace/prod created
```

### 3.3 Verificación de Namespaces
Se consultó el registro completo en el API Server:

```bash
[root@k8s-master 01-namespace]# kubectl get namespaces
NAME              STATUS   AGE
bootcamp          Active   14s
default           Active   11h
dev               Active   9s
kube-flannel      Active   11h
kube-node-lease   Active   11h
kube-public       Active   11h
kube-system       Active   11h
prod              Active   4s
```

### 3.4 Configuración del Contexto Activo
Para evitar la necesidad de ingresar la bandera `-n bootcamp` en cada consulta subsecuente, se modificó el contexto local de `kubectl`:

```bash
[root@k8s-master 01-namespace]# kubectl config set-context --current --namespace=bootcamp
Context "kubernetes-admin@kubernetes" modified.

[root@k8s-master 01-namespace]# kubectl config view --minify | grep namespace
    namespace: bootcamp
```

---

## 4. Lab 02: Despliegue e Inspección de Pod Básico

El **Pod** representa la abstracción fundamental de Kubernetes: encapsula uno o más contenedores estrechamente acoplados que comparten almacenamiento, red (`localhost`) y ciclo de vida.

### 4.1 Definición del Manifiesto `01-pod-basico.yaml`
Ubicación: `/root/kubernetes/02-pod/01-pod-basico.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-nginx
  namespace: bootcamp
  labels:
    app: nginx
    version: "1.0"
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: "100m"
          memory: "64Mi"
        limits:
          cpu: "200m"
          memory: "128Mi"
```

### 4.2 Despliegue del Recurso
Comando ejecutado en el Master:
```bash
[root@k8s-master 02-pod]# kubectl apply -f 01-pod-basico.yaml
pod/pod-nginx created
```

### 4.3 Análisis de Calendarización (Scheduling) e Inspección
Inmediatamente tras la aplicación, se monitoreó la asignación de recursos del clúster:

```bash
[root@k8s-master 02-pod]# kubectl get pods -o wide
NAME        READY   STATUS              RESTARTS   AGE   IP       NODE          NOMINATED NODE   READINESS GATES
pod-nginx   0/1     ContainerCreating   0          4s    <none>   k8s-worker1   <none>           <none>
```

**Observación Técnica:** El planificador (`kube-scheduler`) evaluó las restricciones de afinidad y recursos de los nodos disponibles y determinó programar la carga de trabajo en el nodo Worker (`k8s-worker1`).

Tras la descarga y extracción de la imagen `nginx:1.25` por parte del runtime containerd en el Worker, el estado transitó a `Running`:

```bash
[root@k8s-master 02-pod]# kubectl get pod pod-nginx -o wide
NAME        READY   STATUS    RESTARTS   AGE    IP           NODE          NOMINATED NODE   READINESS GATES
pod-nginx   1/1     Running   0          2m9s   10.244.1.2   k8s-worker1   <none>           <none>
```

* **IP Asignada al Pod:** `10.244.1.2` (Subred Flannel administrada en el nodo Worker).
* **Estado:** `Running (1/1)`.

---

## 5. Lab 02.1: Patrón Sidecar (Múltiples Contenedores en un Pod)

El patrón **Sidecar** consiste en acoplar un contenedor secundario para extender o apoyar la funcionalidad del contenedor principal (por ejemplo: recolección de métricas, agregación de logs o proxy de red) compartiendo el mismo ciclo de vida, espacio de red (`localhost`) y volúmenes de almacenamiento.

### 5.1 Definición del Manifiesto `02-pod-multiples-contenedores.yaml`
Ubicación: `/root/kubernetes/02-pod/02-pod-multiples-contenedores.yaml`

El contenedor `app` escribe un registro en un archivo compartido cada 5 segundos, y el contenedor `sidecar-log-reader` realiza lectura continua (`tail -f`) sobre dicho volumen:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-sidecar
  namespace: bootcamp
  labels:
    app: sidecar-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args:
        - |
          while true; do
            echo "$(date): log de la app" >> /var/log/app.log
            sleep 5
          done
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log

    - name: sidecar-log-reader
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args:
        - |
          tail -f /var/log/app.log
      volumeMounts:
        - name: shared-logs
          mountPath: /var/log

  volumes:
    - name: shared-logs
      emptyDir: {}
```

### 5.2 Despliegue y Validación del Estado
Comando ejecutado en el Master:
```bash
[root@k8s-master 02-pod]# kubectl apply -f 02-pod-multiples-contenedores.yaml
pod/pod-sidecar created

[root@k8s-master 02-pod]# kubectl get pod pod-sidecar -o wide
NAME          READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
pod-sidecar   2/2     Running   0          8s    10.244.1.3   k8s-worker1   <none>           <none>
```

**Observación Técnica:** La columna `READY: 2/2` certifica que ambos contenedores alcanzaron el estado saludable dentro del mismo Pod y fueron ubicados en el nodo `k8s-worker1` con la dirección IP `10.244.1.3`.

### 5.3 Inspección de Logs del Contenedor Sidecar
Al existir más de un contenedor, se empleó la bandera `-c` para dirigir la lectura específicamente al proceso lector:

```bash
[root@k8s-master 02-pod]# kubectl logs pod-sidecar -c sidecar-log-reader -f
Fri Nov  6 14:07:28 UTC 2026: log de la app
Fri Nov  6 14:07:33 UTC 2026: log de la app
Fri Nov  6 14:07:38 UTC 2026: log de la app
```
Se comprobó que el contenedor secundario tiene acceso en tiempo real a los archivos generados por el contenedor principal mediante el volumen compartido `emptyDir`.

---

## 6. Lab 02.2: Patrón Init Container

Los **Init Containers** son contenedores especializados que se ejecutan y completan de manera secuencial antes de que los contenedores de la aplicación principal inicien. Si un Init Container falla, Kubernetes reinicia el Pod según su política hasta que tenga éxito.

### 6.1 Definición del Manifiesto `03-pod-init-container.yaml`
Ubicación: `/root/kubernetes/02-pod/03-pod-init-container.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-init
  namespace: bootcamp
  labels:
    app: init-demo
spec:
  initContainers:
    - name: init-esperar-servicio
      image: busybox:1.36
      command: ["/bin/sh", "-c"]
      args:
        - |
          echo "Esperando que el servicio de base de datos esté listo..."
          sleep 5
          echo "Servicio listo. Iniciando aplicación."

  containers:
    - name: app
      image: nginx:1.25
      ports:
        - containerPort: 80
```

### 6.2 Despliegue y Secuenciamiento del Ciclo de Vida
Comando ejecutado en el Master:
```bash
[root@k8s-master 02-pod]# kubectl apply -f 03-pod-init-container.yaml
pod/pod-init created

[root@k8s-master 02-pod]# kubectl get pod pod-init -o wide
NAME       READY   STATUS            RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
pod-init   0/1     PodInitializing   0          8s    10.244.1.4   k8s-worker1   <none>           <none>
```

**Observación Técnica:** El Pod permaneció transitoriamente en el estado `PodInitializing` mientras el contenedor `init-esperar-servicio` completaba su tarea de validación (simulada con un retardo de 5 segundos). Una vez finalizado exitosamente, el contenedor principal `app` (Nginx) arrancó y el Pod pasó a `Running (1/1)`.

### 6.3 Verificación de Registros del Contenedor de Inicialización
Incluso después de que el Init Container finalizó y se detuvo, sus logs quedaron accesibles para auditoría:

```bash
[root@k8s-master 02-pod]# kubectl logs pod-init -c init-esperar-servicio
Esperando que el servicio de base de datos esté listo...
Servicio listo. Iniciando aplicación.
```

---

## 7. Pruebas de Funcionamiento y Verificación de Servicios

### 5.1 Inspección de Logs del Contenedor
Se consultaron las salidas de consola del servidor web dentro del Pod:

```bash
[root@k8s-master 02-pod]# kubectl logs pod-nginx
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/11/06 13:58:02 [notice] 1#1: using the "epoll" event method
2026/11/06 13:58:02 [notice] 1#1: nginx/1.25.5
2026/11/06 13:58:02 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14)
2026/11/06 13:58:02 [notice] 1#1: OS: Linux 6.12.0-211.16.1.el10_2.0.1.x86_64
2026/11/06 13:58:02 [notice] 1#1: start worker processes
2026/11/06 13:58:02 [notice] 1#1: start worker process 29
2026/11/06 13:58:02 [notice] 1#1: start worker process 30
```
Los registros confirman que los procesos de trabajo de Nginx inicializaron correctamente bajo el kernel del nodo anfitrión.

### 7.2 Exposición y Conectividad Externa vía Port-Forward
Para acceder al Pod desde fuera de la red interna de contenedores, se habilitó un túnel seguro a través del API Server:

```bash
[root@k8s-master 02-pod]# kubectl port-forward pod/pod-nginx 8080:80 --address 0.0.0.0
Forwarding from 0.0.0.0:8080 -> 80
Handling connection for 8080
```

La petición fue procesada de manera exitosa (`Handling connection for 8080`), validando la integridad del tráfico de red entre el plano de control, el nodo de ejecución y el contenedor final.

---

## 8. Lab 03: ConfigMaps y Comparativa de Consumo (Variables vs Volúmenes)

Bajo la metodología *12-Factor App*, la configuración debe desacoplarse del código y de las imágenes de contenedor. Un **ConfigMap** almacena pares clave-valor y archivos de configuración en texto plano que pueden inyectarse en los Pods.

### 8.1 Definición del ConfigMap `app-config`
Ubicación: `/root/kubernetes/03-configmap/01-configmap-literal.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: bootcamp
data:
  APP_ENV: "production"
  APP_PORT: "8080"
  APP_LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"

  app.properties: |
    environment=production
    port=8080
    log.level=info
    max.connections=100

  nginx.conf: |
    server {
      listen 80;
      server_name localhost;
      location / {
        root /usr/share/nginx/html;
        index index.html;
      }
    }
```

Comando ejecutado en el Master:
```bash
[root@k8s-master 03-configmap]# kubectl apply -f 01-configmap-literal.yaml
configmap/app-config created
```

---

### 8.2 Inyección como Variables de Entorno (`envFrom`)
Ubicación: `/root/kubernetes/03-configmap/02-pod-con-configmap-envvar.yaml`

El Pod inyecta todas las claves del ConfigMap directamente como variables en el entorno del proceso:

```bash
[root@k8s-master 03-configmap]# kubectl apply -f 02-pod-con-configmap-envvar.yaml
pod/pod-config-env created

[root@k8s-master 03-configmap]# kubectl exec pod-config-env -- env | grep APP
APP_ENV=production
APP_PORT=8080
APP_LOG_LEVEL=info
```

---

### 8.3 Montaje como Archivos en un Volumen (`volumeMounts`)
Ubicación: `/root/kubernetes/03-configmap/03-pod-con-configmap-volumen.yaml`

Cada clave del ConfigMap se proyecta como un archivo dentro del directorio montado `/etc/app-config/`:

```bash
[root@k8s-master 03-configmap]# kubectl apply -f 03-pod-con-configmap-volumen.yaml
pod/pod-config-vol created

[root@k8s-master 03-configmap]# kubectl exec pod-config-vol -- ls -la /etc/app-config/
total 0
drwxrwxrwx    3 root     root           175 Nov  6 14:22 .
drwxr-xr-x    1 root     root            72 Nov  6 14:22 ..
drwxr-xr-x    2 root     root           121 Nov  6 14:22 ..2026_11_06_14_22_33.1796288597
lrwxrwxrwx    1 root     root            32 Nov  6 14:22 ..data -> ..2026_11_06_14_22_33.1796288597
lrwxrwxrwx    1 root     root            14 Nov  6 14:22 APP_ENV -> ..data/APP_ENV
lrwxrwxrwx    1 root     root            20 Nov  6 14:22 APP_LOG_LEVEL -> ..data/APP_LOG_LEVEL
lrwxrwxrwx    1 root     root            15 Nov  6 14:22 APP_PORT -> ..data/APP_PORT
lrwxrwxrwx    1 root     root            22 Nov  6 14:22 MAX_CONNECTIONS -> ..data/MAX_CONNECTIONS
lrwxrwxrwx    1 root     root            21 Nov  6 14:22 app.properties -> ..data/app.properties
lrwxrwxrwx    1 root     root            17 Nov  6 14:22 nginx.conf -> ..data/nginx.conf
```

**Observación de Arquitectura:** Kubernetes utiliza enlaces simbólicos apuntando a un directorio con timestamp (`..data`). Este diseño permite intercambiar de forma atómica la versión de la configuración sin bloquear las lecturas de los procesos.

---

### 8.4 Demostración de Hot Reload (Slide 17): "Cambio el ConfigMap... ¿quién se entera?"

Se modificó en caliente el valor de `APP_LOG_LEVEL` en el ConfigMap de `info` a `debug` mediante un comando de patch:

```bash
[root@k8s-master 03-configmap]# kubectl patch configmap app-config --type merge -p '{"data":{"APP_LOG_LEVEL":"debug"}}'
configmap/app-config patched

[root@k8s-master 03-configmap]# kubectl get configmap app-config -o jsonpath='{.data.APP_LOG_LEVEL}'
debug
```

#### Comparativa de Resultados:

1. **En el Pod con Volumen (`pod-config-vol`):**
   ```bash
   [root@k8s-master 03-configmap]# kubectl exec pod-config-vol -- cat /etc/app-config/APP_LOG_LEVEL
   debug
   ```
   *Resultado:* **Actualizado en caliente (Hot Reload)**. Kubelet sincronizó el enlace simbólico sin necesidad de reiniciar el Pod.

2. **En el Pod con Variables de Entorno (`pod-config-env`):**
   ```bash
   [root@k8s-master 03-configmap]# kubectl exec pod-config-env -- env | grep APP_LOG_LEVEL
   APP_LOG_LEVEL=info
   ```
   *Resultado:* **No se actualizó**. Las variables de entorno se copian al espacio de memoria del proceso únicamente al momento del arranque. Para actualizar una variable de entorno se requiere destruir o recrear el Pod.

| Característica | Variables de Entorno (`envFrom`) | Montaje de Volumen (`volumeMounts`) |
| :--- | :--- | :--- |
| **Momento de lectura** | Al arrancar el proceso | En cada lectura del sistema de archivos |
| **Actualización en caliente** | No (Requiere reiniciar Pod) | Sí (Sincronizado por Kubelet ~60s) |
| **Mecanismo subyacente** | Copia al entorno del proceso Linux | Enlace simbólico atómico a `..data` |

---

## 9. Lab 04: Gestión de Datos Sensibles con Secrets

Un **Secret** está diseñado para alojar contraseñas, tokens de API, certificados y cadenas de conexión, permitiendo a los operadores restringir su acceso mediante políticas RBAC diferenciadas de los ConfigMaps convencionales.

### 9.1 Definición del Secret `db-credentials`
Ubicación: `/root/kubernetes/04-secret/01-secret.yaml`

Los valores dentro de un manifiesto de Secret de tipo `Opaque` se almacenan codificados en **Base64**:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: bootcamp
  labels:
    app: database
type: Opaque
data:
  DB_USER: YWRtaW4=           # admin
  DB_PASSWORD: bWktcGFzc3dvcmQ=   # mi-password
  DB_HOST: bG9jYWxob3N0       # localhost
  DB_PORT: NTQzMg==           # 5432
```

Comando ejecutado en el Master:
```bash
[root@k8s-master 04-secret]# kubectl apply -f 01-secret.yaml
secret/db-credentials created

[root@k8s-master 04-secret]# kubectl get secrets
NAME             TYPE     DATA   AGE
db-credentials   Opaque   4      6s

[root@k8s-master 04-secret]# kubectl describe secret db-credentials
Name:         db-credentials
Namespace:    bootcamp
Labels:       app=database
Annotations:  <none>

Type:  Opaque

Data
====
DB_HOST:      9 bytes
DB_PASSWORD:  11 bytes
DB_PORT:      4 bytes
DB_USER:      5 bytes
```

**Observación Técnica:** El comando `describe` no imprime los valores por seguridad, sino únicamente el tamaño en bytes de cada entrada.

---

### 9.2 Demostración de Seguridad: Base64 no es Cifrado
Para certificar que Base64 es un esquema de codificación/ofuscación y no de cifrado criptográfico, se extrajo el valor binario del campo `DB_PASSWORD` y se decodificó con el comando del sistema operativo:

```bash
[root@k8s-master 04-secret]# kubectl get secret db-credentials -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
mi-password
```

**Conclusión de Seguridad:** Un Secret en un repositorio Git representa una credencial expuesta. En entornos productivos se debe complementar el uso de Secrets nativos con herramientas de cifrado real y gestión de identidades como HashiCorp Vault, Sealed Secrets o External Secrets Operator.

---

### 9.3 Inyección del Secret en un Pod (`pod-con-secret`)
Ubicación: `/root/kubernetes/04-secret/02-pod-con-secret.yaml`

El Pod consume las claves puntuales del Secret mediante referencias `secretKeyRef`:

```bash
[root@k8s-master 04-secret]# kubectl apply -f 02-pod-con-secret.yaml
pod/pod-con-secret created

[root@k8s-master 04-secret]# kubectl get pod pod-con-secret -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
pod-con-secret   1/1     Running   0          62s   10.244.1.7   k8s-worker1   <none>           <none>
```

El planificador ubicó el Pod en el nodo `k8s-worker1` con la dirección IP `10.244.1.7`.

#### Inspección de Logs y Variables en el Contenedor:
Kubernetes decodifica automáticamente el valor en memoria y lo expone en texto plano al proceso del contenedor:

```bash
[root@k8s-master 04-secret]# kubectl logs pod-con-secret
=== Credenciales disponibles ===
Usuario: admin
Host: localhost:5432
Password: [OCULTO - no imprimir en prod!]

[root@k8s-master 04-secret]# kubectl exec pod-con-secret -- env | grep DB_
DB_USER=admin
DB_PASSWORD=mi-password
DB_HOST=localhost
DB_PORT=5432
```

---

## 10. Lab 05: ServiceAccount y Control de Acceso RBAC

Mientras que los usuarios humanos se autentican ante el API Server mediante certificados o tokens en `kubeconfig`, los Pods requieren una identidad interna denominada **ServiceAccount**. La autorización de las operaciones se regula mediante el modelo **RBAC** (*Role-Based Access Control*).

### 10.1 Definición y Despliegue de RBAC
* **ServiceAccount (`app-serviceaccount`):** Identidad del Pod en el namespace `bootcamp`.
* **Role (`pod-reader`):** Regla que restringe las acciones exclusivamente a los verbos `get`, `list` y `watch` sobre recursos `pods` y `configmaps`.
* **RoleBinding (`pod-reader-binding`):** Asocia el rol `pod-reader` con el sujeto `app-serviceaccount`.

Comandos ejecutados en el Master:
```bash
[root@k8s-master 05-serviceaccount]# kubectl apply -f 01-serviceaccount.yaml
serviceaccount/app-serviceaccount created

[root@k8s-master 05-serviceaccount]# kubectl apply -f 02-role-rolebinding.yaml
role.rbac.authorization.k8s.io/pod-reader created
rolebinding.rbac.authorization.k8s.io/pod-reader-binding created

[root@k8s-master 05-serviceaccount]# kubectl get rolebinding pod-reader-binding
NAME                 ROLE              AGE
pod-reader-binding   Role/pod-reader   19s
```

---

### 10.2 Auditoría de Permisos con `kubectl auth can-i`
Kubernetes permite auditar los privilegios de un ServiceAccount sin necesidad de iniciar sesión como él mediante la bandera `--as`:

```bash
[root@k8s-master 05-serviceaccount]# SA=system:serviceaccount:bootcamp:app-serviceaccount

[root@k8s-master 05-serviceaccount]# kubectl auth can-i list pods --as=$SA -n bootcamp
yes

[root@k8s-master 05-serviceaccount]# kubectl auth can-i delete pods --as=$SA -n bootcamp
no

[root@k8s-master 05-serviceaccount]# kubectl auth can-i create deployments --as=$SA -n bootcamp
no
```

**Conclusión de Seguridad:** Se comprobó el cumplimiento estricto del principio de menor privilegio. La cuenta de servicio tiene permiso de lectura (`yes`), pero el API Server rechaza cualquier intento de borrado o creación de recursos administrativos (`no`).

---

### 10.3 Inyección del Token JWT en el Pod (`pod-api-caller`)
Ubicación: `/root/kubernetes/05-serviceaccount/03-pod-con-serviceaccount.yaml`

El Pod monta automáticamente el token de la cuenta de servicio en la ruta estándar `/var/run/secrets/kubernetes.io/serviceaccount/`:

```bash
[root@k8s-master 05-serviceaccount]# kubectl apply -f 03-pod-con-serviceaccount.yaml
pod/pod-api-caller created

[root@k8s-master 05-serviceaccount]# kubectl logs pod-api-caller
=== Llamando a la API de Kubernetes ===
Namespace actual: bootcamp

--- Pods en el namespace bootcamp ---

=== Token del ServiceAccount (primeros 50 chars) ===
eyJhbGciOiJSUzI1NiIsImtpZCI6ImxzRzh4cDNwV29LdXJFN0...

[root@k8s-master 05-serviceaccount]# kubectl exec pod-api-caller -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
total 0
drwxrwxrwt    3 root     root           140 Nov  6 14:45 .
drwxr-xr-x    3 root     root            28 Nov  6 14:45 ..
drwxr-xr-x    2 root     root           100 Nov  6 14:45 ..2026_11_06_14_45_07.2130339748
lrwxrwxrwx    1 root     root            32 Nov  6 14:45 ..data -> ..2026_11_06_14_45_07.2130339748
lrwxrwxrwx    1 root     root            13 Nov  6 14:45 ca.crt -> ..data/ca.crt
lrwxrwxrwx    1 root     root            16 Nov  6 14:45 namespace -> ..data/namespace
lrwxrwxrwx    1 root     root            12 Nov  6 14:45 token -> ..data/token
```

---

## 11. Lab 06: Deployments, Estrategia Rolling Update y Rollback

Un **Deployment** es la abstracción de nivel superior encargada de orquestar réplicas de Pods mediante **ReplicaSets**, proporcionando capacidades de auto-recuperación (*self-healing*), escalabilidad y despliegues sin tiempo de inactividad (*zero-downtime*).

### 11.1 Despliegue Inicial y Verificación de Jerarquía
Ubicación: `/root/kubernetes/06-deployment/01-deployment.yaml`

Se definió un Deployment con 3 réplicas de Nginx, configurado con `livenessProbe` y estrategia `RollingUpdate` (`maxSurge: 1`, `maxUnavailable: 1`):

```bash
[root@k8s-master 06-deployment]# kubectl apply -f 01-deployment.yaml
deployment.apps/nginx-deployment created

[root@k8s-master 06-deployment]# kubectl get deploy,rs,pods -l app=nginx -o wide
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   3/3     3            3           45s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-deployment-7d5c8448b5   3         3         3       45s
```

---

### 11.2 Escalado Elástico Horizontal
Se demostró la capacidad de escalar la aplicación bajo demanda de 3 a 5 réplicas:

```bash
[root@k8s-master 06-deployment]# kubectl scale deployment nginx-deployment --replicas=5
deployment.apps/nginx-deployment scaled

[root@k8s-master 06-deployment]# kubectl get pods -l app=nginx
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-cd6bb9bd4-49wm9   1/1     Running   0          2m32s
nginx-deployment-cd6bb9bd4-76t4z   1/1     Running   0          111s
nginx-deployment-cd6bb9bd4-7g562   1/1     Running   0          2m2s
nginx-deployment-cd6bb9bd4-bj9jq   1/1     Running   0          2m33s
nginx-deployment-cd6bb9bd4-t5d98   1/1     Running   0          2m1s
```

---

### 11.3 Rolling Update (Actualización Progresiva a Nginx 1.26)
Se actualizó la versión de la imagen en vivo sin interrumpir la atención de peticiones:

```bash
[root@k8s-master 06-deployment]# kubectl set image deployment/nginx-deployment nginx=nginx:1.26
deployment.apps/nginx-deployment image updated

[root@k8s-master 06-deployment]# kubectl get rs
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-7d5c8448b5   0         0         0       2m8s
nginx-deployment-cd6bb9bd4    5         5         5       99s

[root@k8s-master 06-deployment]# kubectl rollout history deployment/nginx-deployment
deployment.apps/nginx-deployment 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

**Observación Técnica:** El Deployment generó un nuevo ReplicaSet (`cd6bb9bd4`) con 5 réplicas y redujo el anterior (`7d5c8448b5`) a 0. El ReplicaSet original se preserva intacto en el clúster para permitir una reversión inmediata si fuera necesario.

---

### 11.4 Demostración de Falla de Imagen y Rollback Automático
Se simuló un error humano en producción actualizando el Deployment hacia una etiqueta de imagen inexistente (`nginx:version-no-existe`):

```bash
[root@k8s-master 06-deployment]# kubectl set image deployment/nginx-deployment nginx=nginx:version-no-existe
deployment.apps/nginx-deployment image updated
```

Al detectar que la nueva versión no puede descargar la imagen, el ciclo de despliegue se detiene automáticamente, manteniendo las réplicas saludables en ejecución.

Para restaurar el estado estable anterior se ejecutó una reversión (*Rollback*):

```bash
[root@k8s-master 06-deployment]# kubectl rollout undo deployment/nginx-deployment
deployment.apps/nginx-deployment rolled back

[root@k8s-master 06-deployment]# kubectl rollout status deployment/nginx-deployment
Waiting for deployment "nginx-deployment" rollout to finish: 0 out of 5 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 out of 5 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 2 out of 5 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 3 out of 5 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 4 out of 5 new replicas have been updated...
Waiting for deployment "nginx-deployment" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "nginx-deployment" rollout to finish: 4 of 5 updated replicas are available...
deployment "nginx-deployment" successfully rolled out
```

El clúster completó la rotación de pods sin caída y restauró las 5 réplicas a su versión funcional comprobada.

---

### 11.5 Integración Completa de Producción y Demostración de Auto-Recuperación (Self-Healing)
Ubicación: `/root/kubernetes/06-deployment/02-deployment-con-config.yaml`

En el Slide 25 se evaluó el patrón arquitectónico final de producción, integrando en un único flujo de despliegue un **ConfigMap** (`webapp-config`), un **Secret** (`webapp-secret`), un **ServiceAccount** (`app-serviceaccount`) y un **Deployment** de 2 réplicas (`webapp-deployment`).

Comando ejecutado en el Master:
```bash
[root@k8s-master 06-deployment]# kubectl apply -f 02-deployment-con-config.yaml
configmap/webapp-config created
secret/webapp-secret created
deployment.apps/webapp-deployment created
```

#### Verificación de Inyección de Credenciales y Configuración:
Se comprobó que el Pod montó exitosamente tanto la variable del ConfigMap como la llave decodificada del Secret:

```bash
[root@k8s-master 06-deployment]# POD=$(kubectl get pods -l app=webapp -o jsonpath='{.items[0].metadata.name}')
[root@k8s-master 06-deployment]# kubectl exec $POD -- env | grep -E 'APP_ENV|API_KEY'
APP_ENV=production
API_KEY=super-secret-key
```

#### Demostración Práctica de Auto-recuperación (Self-Healing):
Se simuló la caída abrupta del proceso principal de la aplicación enviando una señal de parada al servidor web (`nginx -s stop`):

```bash
[root@k8s-master 06-deployment]# kubectl exec $POD -- nginx -s stop
2026/11/06 15:06:02 [notice] 38#38: signal process started

[root@k8s-master 06-deployment]# kubectl get pods -l app=webapp
NAME                                 READY   STATUS    RESTARTS   AGE
webapp-deployment-856bc68674-bv754   1/1     Running   1          29s
webapp-deployment-856bc68674-kx9pf   1/1     Running   0          29s
```

**Observación Técnica:** El agente Kubelet detectó de inmediato el cese del proceso contenedor y lo reinició de forma autónoma. La columna `RESTARTS` transitó de `0` a `1` preservando la disponibilidad del Pod sin requerir intervención manual del operador.

---

## 12. Conclusiones

1. **Aislamiento Estructurado:** El uso de Namespaces permitió segmentar el clúster eficientemente, estableciendo las bases para la gobernanza multi-entorno (`bootcamp`, `dev`, `prod`).
2. **Orquestación Multi-Nodo:** Se demostró la capacidad de Kubernetes para recibir manifiestos en el Control Plane y distribuir la ejecución de las cargas de trabajo de manera transparente hacia el nodo Worker (`k8s-worker1`).
3. **Patrón Sidecar:** Se comprobó la utilidad de compartir volúmenes en memoria (`emptyDir`) entre múltiples contenedores dentro del mismo Pod (`2/2`), permitiendo desacoplar la generación de logs de su consumo.
4. **Patrón Init Container:** Se validó la secuenciación de dependencias previas al arranque del servicio principal (`PodInitializing` -> `Running 1/1`), garantizando que la aplicación sólo inicie cuando sus prerrequisitos estén cumplidos.
5. **Comportamiento de ConfigMaps (Hot Reload):** La práctica demostró empíricamente la diferencia crítica de arquitectura entre consumir configuraciones vía variables de entorno vs volúmenes. Se comprobó que el montaje de volúmenes soporta actualización en caliente (`debug`), mientras que las variables de entorno permanecen estáticas (`info`) hasta el reinicio del Pod.
6. **Seguridad y Gestión de Secrets:** Se verificó que los Secrets aíslan el acceso administrativo mediante RBAC y que Kubernetes gestiona su decodificación automática en tiempo de ejecución. Asimismo, se demostró mediante extracción directa que Base64 no constituye cifrado, reforzando la necesidad de aplicar operadores de secretos externos en arquitecturas de producción.
7. **Control de Acceso Basado en Roles (RBAC):** Se confirmó que las aplicaciones dentro de Pods pueden interactuar de forma segura con el API Server mediante tokens JWT montados automáticamente, limitando sus acciones mediante `Role` y `RoleBinding` bajo el principio de menor privilegio auditado con `kubectl auth can-i`.
8. **Resiliencia, Despliegue Continuo y Auto-Recuperación:** Se demostró la capacidad integral de los Deployments para mantener réplicas declaradas, absorber fallas de actualización mediante *Rollbacks* y restablecer automáticamente servicios caídos (*Self-Healing* con incremento en el contador de reinicios).






