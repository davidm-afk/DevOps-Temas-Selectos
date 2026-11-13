# 📑 Reporte de Evidencias: Ejercicio Integrador Kubernetes (Parte 1)

**Materia:** Temas Selectos de Redes y Seguridad (TSIC2 / DevOps)  
**Profesor:** Daniel Guerrero  
**Fecha de Entrega:** Noviembre 2026  
**Sistema Operativo:** Rocky Linux 10.2 (Red Quartz)  
**Versión de Kubernetes:** v1.31.14 (containerd v2.4.2 + Flannel CNI)  
**Nodo / IP:** `192.168.71.128` (Puerto expuesto: `30090`)

---

## 🎯 1. Resumen Ejecutivo y Objetivos

El ejercicio consiste en desplegar de forma declarativa y unificada la integración de los objetos fundamentales de Kubernetes en un único manifiesto (`todo-en-uno.yaml`) y verificar la resolución de los retos prácticos:
1. **Namespace:** Aislamiento lógico del entorno (`mi-app`).
2. **ServiceAccount:** Identidad de ejecución segura (`mi-app-sa`).
3. **ConfigMap:** Inyección desacoplada de variables de entorno y montaje de volumen HTML (`mi-app-config`).
4. **Secret:** Manejo protegido de credenciales en Base64 (`mi-app-secret`).
5. **Deployment:** Orquestación elástica de 3 réplicas con probes de salud (`readiness` y `liveness`) y política `RollingUpdate`.
6. **Service (NodePort):** Exposición exterior a través del puerto `30090`.
7. **Retos y Resiliencia:** Demostración de autorrecuperación (*self-healing*) y escalado elástico dinámico (escalado a 5 réplicas y reducción a 3).

---

## 🏗️ 2. Manifiesto Declarativo Unificado (`todo-en-uno.yaml`)

Se diseñó y aplicó el manifiesto en `/root/todo-en-uno.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mi-app
  labels:
    env: demo
    team: devops
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mi-app-sa
  namespace: mi-app
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mi-app-config
  namespace: mi-app
data:
  APP_ENV: "demo"
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Kubernetes Demo</title>
    <style>
      body { font-family: Arial, sans-serif; background: #1a1a2e; color: #eee; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
      .card { background: #16213e; border-radius: 12px; padding: 40px; text-align: center; box-shadow: 0 4px 20px rgba(0,0,0,0.4); max-width: 500px; }
      h1 { color: #0f9b58; font-size: 2em; }
      .badge { background: #0f9b58; color: white; padding: 4px 12px; border-radius: 20px; font-size: 0.8em; margin: 4px; display: inline-block; }
    </style>
    </head>
    <body>
    <div class="card">
      <h1>&#x2705; ¡Hola desde Kubernetes!</h1>
      <p>Desplegada con:</p>
      <span class="badge">Namespace</span>
      <span class="badge">ServiceAccount</span>
      <span class="badge">ConfigMap</span>
      <span class="badge">Secret</span>
      <span class="badge">Deployment</span>
      <span class="badge">Service NodePort</span>
      <p style="margin-top:20px; color:#aaa; font-size:0.85em;">DevOps TSIC2 &bull; Rocky Linux 10 &bull; Kubernetes v1.31.14</p>
    </div>
    </body>
    </html>
---
apiVersion: v1
kind: Secret
metadata:
  name: mi-app-secret
  namespace: mi-app
type: Opaque
data:
  API_KEY: c3VwZXItc2VjcmV0LWFwaS1rZXktMTIzNDU=   # super-secret-api-key-12345
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-app-deployment
  namespace: mi-app
  labels:
    app: mi-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mi-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: mi-app
    spec:
      serviceAccountName: mi-app-sa
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: mi-app-config
                  key: APP_ENV
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: mi-app-secret
                  key: API_KEY
          volumeMounts:
            - name: html-volume
              mountPath: /usr/share/nginx/html
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 20
      volumes:
        - name: html-volume
          configMap:
            name: mi-app-config
            items:
              - key: index.html
                path: index.html
---
apiVersion: v1
kind: Service
metadata:
  name: mi-app-service
  namespace: mi-app
spec:
  type: NodePort
  selector:
    app: mi-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30090
```

---

## 📸 3. Evidencias de Ejecución y Pruebas

### Evidencia 1: Estado Operativo del Clúster y Pods de Sistema
```text
[root@localhost ~]# kubectl get nodes -o wide
NAME                    STATUS   ROLES           AGE     VERSION    INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION                      CONTAINER-RUNTIME
localhost.localdomain   Ready    control-plane   2m56s   v1.31.14   192.168.71.128   <none>        Rocky Linux 10.2 (Red Quartz)   6.12.0-211.16.1.el10_2.0.1.x86_64   containerd://2.4.2

[root@localhost ~]# kubectl get pods -n kube-system
NAME                                            READY   STATUS    RESTARTS   AGE
coredns-7c65d6cfc9-bmvxj                        1/1     Running   0          2m47s
coredns-7c65d6cfc9-xhgzf                        1/1     Running   0          2m47s
etcd-localhost.localdomain                      1/1     Running   0          2m53s
kube-apiserver-localhost.localdomain            1/1     Running   0          2m53s
kube-controller-manager-localhost.localdomain   1/1     Running   0          2m53s
kube-proxy-h54nn                                1/1     Running   0          2m48s
kube-scheduler-localhost.localdomain            1/1     Running   0          2m53s

[root@localhost ~]# kubectl get pods -n kube-flannel
NAME                    READY   STATUS    RESTARTS   AGE
kube-flannel-ds-ts6c4   1/1     Running   0          2m40s
```

---

### Evidencia 2: Despliegue Unificado de los 6 Objetos en el Namespace `mi-app`
```text
[root@localhost ~]# kubectl get all,sa,configmap,secret -n mi-app -o wide
NAME                                    READY   STATUS    RESTARTS   AGE   IP           NODE                    NOMINATED NODE   READINESS GATES
pod/mi-app-deployment-bbd479cc4-2ntl6   1/1     Running   0          98s   10.244.0.5   localhost.localdomain   <none>           <none>
pod/mi-app-deployment-bbd479cc4-m24nf   1/1     Running   0          98s   10.244.0.4   localhost.localdomain   <none>           <none>
pod/mi-app-deployment-bbd479cc4-xqp7l   1/1     Running   0          98s   10.244.0.6   localhost.localdomain   <none>           <none>

NAME                     TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/mi-app-service   NodePort   10.97.84.10   <none>        80:30090/TCP   98s   app=mi-app

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES       SELECTOR
deployment.apps/mi-app-deployment   3/3     3            3           98s   nginx        nginx:1.25   app=mi-app

NAME                                          DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES       SELECTOR
replicaset.apps/mi-app-deployment-bbd479cc4   3         3         3       98s   nginx        nginx:1.25   app=mi-app,pod-template-hash=bbd479cc4

NAME                       SECRETS   AGE
serviceaccount/default     0         98s
serviceaccount/mi-app-sa   0         98s

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      98s
configmap/mi-app-config      2      98s

NAME                   TYPE     DATA   AGE
secret/mi-app-secret   Opaque   1      98s
```

---

### Evidencia 3: Auditoría Interna de Variables y Secretos Inyectados
Validación de que el Pod consume correctamente tanto el ConfigMap como el Secret desencriptado en tiempo de ejecución:

```text
[root@localhost ~]# POD=$(kubectl get pods -n mi-app -l app=mi-app -o jsonpath='{.items[0].metadata.name}')
[root@localhost ~]# kubectl exec -n mi-app $POD -- env | grep -E 'APP_ENV|API_KEY'
APP_ENV=demo
API_KEY=super-secret-api-key-12345
```

---

### Evidencia 4: Verificación del Volumen HTML Montado desde ConfigMap
```text
[root@localhost ~]# kubectl exec -n mi-app $POD -- cat /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><title>Kubernetes Demo</title>
...
<h1>&#x2705; ¡Hola desde Kubernetes!</h1>
<p>Desplegada con:</p>
<span class="badge">Namespace</span>
<span class="badge">ServiceAccount</span>
<span class="badge">ConfigMap</span>
<span class="badge">Secret</span>
<span class="badge">Deployment</span>
<span class="badge">Service NodePort</span>
...
</html>
```

---

### Evidencia 5: Acceso HTTP al Servicio NodePort (Puerto 30090)
Verificación exitosa desde la terminal de la máquina virtual y desde el host Windows físico (`http://192.168.71.128:30090`):

```text
HTTP/1.1 200 OK
Server: nginx/1.25.5
Date: Fri, 13 Nov 2026 05:56:34 GMT
Content-Type: text/html
Content-Length: 1072
Connection: keep-alive
```

---

### Evidencia 6 (Reto 1): Autorrecuperación (*Self-Healing*)
Se eliminó intencionalmente uno de los pods activos para auditar la reconciliación autónoma del ReplicaSet:

```text
[root@localhost ~]# kubectl delete pod mi-app-deployment-bbd479cc4-2ntl6 -n mi-app
pod "mi-app-deployment-bbd479cc4-2ntl6" deleted

[root@localhost ~]# kubectl get pods -n mi-app
NAME                                READY   STATUS    RESTARTS   AGE
mi-app-deployment-bbd479cc4-ghwh4   1/1     Running   0          4s
mi-app-deployment-bbd479cc4-m24nf   1/1     Running   0          103s
mi-app-deployment-bbd479cc4-xqp7l   1/1     Running   0          103s
```
*Observación:* En menos de 4 segundos, el controlador generó el nuevo pod de reemplazo `ghwh4` manteniendo la cuota de 3 pods saludables sin interrupción de servicio.

---

### Evidencia 7 (Reto 2): Escalabilidad Dinámica y Elástica
Se probó la capacidad de absorción de carga escalando el deployment a 5 réplicas:

```text
[root@localhost ~]# kubectl scale deployment mi-app-deployment --replicas=5 -n mi-app
deployment.apps/mi-app-deployment scaled

[root@localhost ~]# kubectl get pods -n mi-app -o wide
NAME                                READY   STATUS    RESTARTS   AGE    IP           NODE
mi-app-deployment-bbd479cc4-7kd8n   1/1     Running   0          11s    10.244.0.9   localhost.localdomain
mi-app-deployment-bbd479cc4-ghwh4   1/1     Running   0          15s    10.244.0.7   localhost.localdomain
mi-app-deployment-bbd479cc4-lpkgg   1/1     Running   0          11s    10.244.0.8   localhost.localdomain
mi-app-deployment-bbd479cc4-m24nf   1/1     Running   0          114s   10.244.0.4   localhost.localdomain
mi-app-deployment-bbd479cc4-xqp7l   1/1     Running   0          114s   10.244.0.6   localhost.localdomain
```

Y posterior reajuste ordenado al estado base de 3 réplicas:
```text
[root@localhost ~]# kubectl scale deployment mi-app-deployment --replicas=3 -n mi-app
deployment.apps/mi-app-deployment scaled
```

---

## 🏁 4. Conclusiones

1. **Integración Completa:** Se demostró la convergencia de todos los componentes de cómputo, red, almacenamiento lógico y seguridad en Kubernetes bajo un único manifiesto declarativo.
2. **Desacoplamiento Efectivo:** Ni la configuración (`APP_ENV`) ni los secretos (`API_KEY`) ni la interfaz gráfica fueron incrustados dentro de la imagen base de Nginx, respetando los estándares de *12-Factor App*.
3. **Resiliencia Operativa:** Las pruebas de estrés y eliminación forzada confirmaron la capacidad nativa de self-healing y escalado horizontal de Kubernetes.

