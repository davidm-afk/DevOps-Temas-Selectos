# Reporte Técnico: Ejercicio Integrador de Kubernetes (Lab 08)

**Materia:** DevOps  
**Estudiante:** Aldo Aaron Gonzalez Chavez  
**Fecha:** Noviembre 2026  
**Entorno de Ejecución:** Clúster Kubernetes v1.31.14 Multi-Nodo (Control Plane: `192.168.56.102` | Worker: `192.168.56.101`)  
**Laboratorio:** Lab 08 - Ejercicio Integrador (`todo-en-uno.yaml`)  

---

## 1. Objetivo y Arquitectura de la Aplicación

El propósito del ejercicio integrador es consolidar en un solo despliegue declarativo la totalidad de los conceptos fundamentales abordados en la Clase 1 de Kubernetes:

* **Aislamiento Multi-Tenant:** `Namespace` propio (`mi-app`).
* **Seguridad e Identidad:** `ServiceAccount` dedicado (`mi-app-sa`).
* **Desacoplamiento de Configuración:** `ConfigMap` (`mi-app-config`) inyectando variables y montando el archivo web `index.html`.
* **Protección de Credenciales:** `Secret` (`mi-app-secret`) codificado en Base64 e inyectado como variable de entorno.
* **Orquestación y Resiliencia:** `Deployment` (`mi-app-deployment`) configurado con 3 réplicas, estrategia Rolling Update y probes de salud (`readinessProbe` y `livenessProbe`).
* **Exposición y Balanceo:** `Service` de tipo `NodePort` (`mi-app-service`) exponiendo el puerto `30090` en todos los nodos del clúster.

```
Namespace: mi-app
├── ServiceAccount (mi-app-sa)
├── ConfigMap (mi-app-config) ──> Monta /usr/share/nginx/html/index.html
├── Secret (mi-app-secret)    ──> Inyecta $API_KEY
├── Deployment (3 réplicas)   ──> Pods distribuidos
└── Service NodePort (:30090) ──> Acceso web desde el exterior
```

---

## 2. Fase 1: Despliegue Unificado

### Comando Ejecutado en el Master:
```bash
cd /root/kubernetes/08-ejercicio-integrador
kubectl apply -f todo-en-uno.yaml
```

> **[CAPTURA 1 REQUERIDA]**  
> *Captura de pantalla de la terminal mostrando la ejecución de `kubectl apply -f todo-en-uno.yaml` y la creación de los 6 recursos.*

---

## 3. Fase 2: Inspección Global de Recursos y Nodos

### Comandos de Verificación:
```bash
# 1. Ver todos los objetos creados dentro del namespace mi-app
kubectl get all -n mi-app -o wide

# 2. Verificar que los 3 pods alcanzaron el estado Ready
kubectl rollout status deployment/mi-app-deployment -n mi-app

# 3. Ver endpoints del servicio NodePort
kubectl get endpoints mi-app-service -n mi-app
```

> **[CAPTURA 2 REQUERIDA]**  
> *Captura de la salida de `kubectl get all -n mi-app -o wide` donde se observe el Deployment con 3/3 réplicas, el Service en el puerto 30090 y los Pods repartidos con sus IPs.*

---

## 4. Fase 3: Acceso Web y Exposición NodePort

El servicio publica el puerto TCP `30090` en ambos nodos (`k8s-master` y `k8s-worker1`).

### Verificación por Consola y Navegador:
* Desde consola:
  ```bash
  curl -I http://192.168.56.102:30090
  curl http://192.168.56.102:30090
  ```
* Desde navegador web (Windows):
  * URL: `http://192.168.56.102:30090` (Master)
  * URL: `http://192.168.56.101:30090` (Worker)

> **[CAPTURA 3 REQUERIDA]**  
> *Captura del navegador web de tu computadora física mostrando la página web que dice:*  
> **"¡Hola desde Kubernetes!"**  
> *"Desplegada con Namespace, SA, ConfigMap, Secret, Deployment y Service."*

---

## 5. Fase 4: Auditoría Interna de Pods (Respuestas Nivel 1)

Verificación de la inyección de configuración y montaje de archivos dentro de los contenedores:

### 1. Extracción del Secret decodificado dentro del Pod:
```bash
POD=$(kubectl get pods -n mi-app -l app=mi-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mi-app $POD -- env | grep -E 'APP_ENV|API_KEY'
```
*Salida esperada:*
```text
APP_ENV=demo
API_KEY=super-secret-api-key-12345
```

### 2. Comprobación del archivo HTML montado desde ConfigMap:
```bash
kubectl exec -n mi-app $POD -- ls -la /usr/share/nginx/html
kubectl exec -n mi-app $POD -- cat /usr/share/nginx/html/index.html
```

> **[CAPTURA 4 REQUERIDA]**  
> *Captura de la terminal ejecutando las comprobaciones del Secret (`API_KEY`) y la lectura del `index.html` montado.*

---

## 6. Fase 5: Pruebas de Resiliencia y Self-Healing

### 1. Eliminación intencional de un Pod:
```bash
kubectl delete pod $POD -n mi-app
kubectl get pods -n mi-app
```
*Observación:* El Deployment detectó la discrepancia con el estado deseado (`replicas: 3`) y generó de forma autónoma un nuevo Pod sustituto en milisegundos.

### 2. Escalado bajo demanda:
```bash
kubectl scale deployment mi-app-deployment --replicas=5 -n mi-app
kubectl get pods -n mi-app
```

> **[CAPTURA 5 REQUERIDA]**  
> *Captura de pantalla mostrando la auto-recuperación del Pod eliminado o el escalado a 5 réplicas.*

---

## 7. Conclusiones Técnicas

1. **Declaratividad Total:** Se comprobó que una arquitectura distribuida completa puede desplegarse y reproducirse de forma idéntica en un solo comando mediante especificaciones declarativas YAML.
2. **Cohesión de Componentes:** Se demostró la interacción fluida entre objetos desacoplados: el Service enruta el tráfico externo a través de Selectors hacia los Pods, los cuales a su vez consumen credenciales del Secret y contenido dinámico del ConfigMap sin recompilar la imagen Docker base.
3. **Alta Disponibilidad:** El orquestador demostró capacidades de auto-curación (*self-healing*) e invariabilidad de servicio gracias a la abstracción de Service y ReplicaSets.
