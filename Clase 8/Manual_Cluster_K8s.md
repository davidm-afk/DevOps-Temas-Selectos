# 📘 Bitácora y Reporte Técnico: Implementación de Clúster Kubernetes con Ansible en Rocky Linux 9

**Materia:** DevOps  
**Objetivo:** Automatizar los prerrequisitos del sistema con Ansible e implementar un clúster Kubernetes funcional compuesto por 1 nodo Control Plane (Master) y 1 nodo Worker.

---

## 📑 Tabla de Contenidos
1. [Arquitectura y Direccionamiento IP](#1-arquitectura-y-direccionamiento-ip)
2. [¿Cómo Conectarse a las Máquinas Virtuales?](#-cómo-conectarse-a-las-máquinas-virtuales)
3. [Solución al Problema de Red (Host-Only + NAT)](#3-solución-al-problema-de-red-host-only--nat)
4. [Clonación de la Máquina Worker](#4-clonación-de-la-máquina-worker)
5. [Identidad de los Nodos (Hostname y /etc/hosts)](#5-identidad-de-los-nodos-hostname-y-etchosts)
6. [Automatización con Ansible (Prerrequisitos)](#6-automatización-con-ansible-prerrequisitos)
7. [Resolución de Incidencias Durante la Práctica](#7-resolución-de-incidencias-durante-la-práctica)
8. [Inicialización del Control Plane (Master)](#8-inicialización-del-control-plane-master)
9. [Despliegue de la Red de Pods (CNI - Flannel)](#9-despliegue-de-la-red-de-pods-cni---flannel)
10. [Unión del Nodo Worker al Clúster](#10-unión-del-nodo-worker-al-clúster)
11. [Comandos de Verificación y Evidencias](#11-comandos-de-verificación-y-evidencias)

---

## 1. Arquitectura y Direccionamiento IP

Para garantizar el aislamiento del laboratorio y al mismo tiempo permitir la descarga de paquetes desde Internet, se diseñó un esquema de doble interfaz de red por máquina virtual:

| Nodo | Rol | Hostname | IP Privada (Host-Only `enp0s8`) | IP Internet (NAT `enp0s3`) | Recursos Asignados |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **VM 1** | Control Plane (Master) | `k8s-master` | `192.168.56.102` | `10.0.2.15` | 2 vCPU / 2048 MB RAM / 20 GB Disco |
| **VM 2** | Worker Node | `k8s-worker1` | `192.168.56.101` | `10.0.2.15` | 2 vCPU / 2048 MB RAM / 20 GB Disco |

---

## 🔌 ¿Cómo Conectarse a las Máquinas Virtuales?

Puedes conectarte a cualquiera de las dos máquinas mediante **SSH** directamente desde tu máquina física (Windows) usando la terminal integrada de VS Code, PowerShell o Windows Terminal.

> [!NOTE]
> Las máquinas virtuales deben estar **iniciadas en VirtualBox** antes de lanzar los comandos de conexión.

### 💻 Conexión al Nodo Master (Control Plane)
Abre una terminal en Windows o VS Code y ejecuta:
```powershell
ssh root@192.168.56.102
```
* **Usuario:** `root`
* **Contraseña:** *(la contraseña de root que le asignaste a tu Rocky Linux)*

---

### 💻 Conexión al Nodo Worker
Abre otra pestaña o terminal dividida y ejecuta:
```powershell
ssh root@192.168.56.101
```
* **Usuario:** `root`
* **Contraseña:** *(la misma contraseña de root)*

---

### 💡 Consejos útiles para la sesión SSH:
1. **Primera conexión (Aceptación de fingerprint):**  
   Si es la primera vez que te conectas, Windows te preguntará:  
   `Are you sure you want to continue connecting (yes/no/[fingerprint])?`  
   Escribe **`yes`** y presiona **Enter**.
2. **Dividir terminales en VS Code:**  
   Presiona `Ctrl + Shift + 5` (o el botón `Split Terminal` arriba a la derecha del panel de terminal) para tener el Master a la derecha y el Worker a la izquierda simultáneamente.
3. **Si recibes error de Host Key (WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED):**  
   Si en algún momento reinstalas o clonas de nuevo y no te deja entrar por conflicto de llaves, límpiala en PowerShell con:
   ```powershell
   ssh-keygen -R 192.168.56.102
   ssh-keygen -R 192.168.56.101
   ```


---

## 2. Solución al Problema de Red (Host-Only + NAT)

### Problema Inicial
Inicialmente se intentó usar el modo *Adaptador Puente (Bridged)* sobre la red inalámbrica de la escuela/oficina. Dado que estas redes públicas o corporativas aplican aislamiento de clientes (*Client Isolation*), las peticiones SSH arrojaban `Connection timed out`.

### Solución Implementada
En los ajustes de red de VirtualBox se configuraron dos tarjetas en cada VM:
* **Adaptador 1 (NAT):** Salida directa a Internet para descargar paquetes (`dnf`, repositorios de Kubernetes y Docker).
* **Adaptador 2 (Adaptador sólo-anfitrión / Host-Only `192.168.56.x`):** Conexión SSH estable e instantánea desde la terminal del Host (Windows) y comunicación bidireccional punto a punto entre las dos máquinas.

---

## 3. Clonación de la Máquina Worker

A partir de la máquina virtual inicial `Rocky-Linux-DevOps`:
1. Se apagó la máquina virtual (`poweroff`).
2. Se realizó una **Clonación Completa** (*Full Clone*) con el nombre `Rocky-Linux-DevOps-worker`.
3. **Punto clave:** Se seleccionó la opción de **"Generar nuevas direcciones MAC para todos los adaptadores de red"** para evitar colisiones de paquetes en la red Host-Only.

---

## 4. Identidad de los Nodos (Hostname y /etc/hosts)

Para que los componentes de Kubernetes y los nodos se reconozcan por nombre canónico:

### En el Master (`192.168.56.102`):
```bash
hostnamectl set-hostname k8s-master
sed -i '/k8s-/d; /10.27./d; /10.39./d' /etc/hosts
cat << 'EOF' >> /etc/hosts
192.168.56.102 k8s-master
192.168.56.101 k8s-worker1
EOF
```

### En el Worker (`192.168.56.101`):
```bash
hostnamectl set-hostname k8s-worker1
sed -i '/k8s-/d; /10.27./d; /10.39./d' /etc/hosts
cat << 'EOF' >> /etc/hosts
192.168.56.102 k8s-master
192.168.56.101 k8s-worker1
EOF
```

### Prueba de Conectividad Cruzada:
```bash
# Desde el Master:
ping -c 3 k8s-worker1

# Desde el Worker:
ping -c 3 k8s-master
```
*(Resultado: 0% packet loss).*

---

## 5. Automatización con Ansible (Prerrequisitos)

Se utilizó el playbook `k8s_prerequisitos.yml` para configurar los 7 requerimientos del sistema exigidos por Kubernetes:

1. **Desactivar Swap:** `swapoff -a` y comentar entradas en `/etc/fstab` (Kubelet requiere memoria fija predecible).
2. **SELinux en modo Permissive:** Edición de `/etc/selinux/config` y `setenforce 0`.
3. **Deshabilitar Firewalld:** Para evitar el bloqueo de puertos del API Server (`6443`), etcd y pods en el laboratorio.
4. **Módulos del Kernel:** Cargar `overlay` y `br_netfilter` en `/etc/modules-load.d/k8s.conf` y en memoria con `modprobe`.
5. **Parámetros Sysctl:**
   * `net.bridge.bridge-nf-call-iptables = 1`
   * `net.bridge.bridge-nf-call-ip6tables = 1`
   * `net.ipv4.ip_forward = 1`
6. **Container Runtime (`containerd`):** Repositorio Docker CE, instalación de `containerd.io`, generación de `/etc/containerd/config.toml` con `SystemdCgroup = true` e inicio de servicio.
7. **Paquetes Kubernetes (v1.31):** Repositorio `pkgs.k8s.io`, instalación y habilitación de `kubelet`, `kubeadm` y `kubectl`.

### Ejecución del Playbook:
```bash
cd /root/devops2026/ansible
ansible-playbook k8s_prerequisitos.yml
```

**Resultado:**
```text
PLAY RECAP *********************************************************************
nodo1                      : ok=19   changed=1    unreachable=0    failed=0    skipped=1
```

---

## 6. Resolución de Incidencias Durante la Práctica

| Incidencia | Causa Raíz | Solución Aplicada |
| :--- | :--- | :--- |
| **La VM se congeló en el paso 7** | Caída de sesión por memoria o corte de red durante la descarga de DNF. | Se reinició la VM y se verificó que el archivo `/usr/bin/kubeadm` había quedado en `0 bytes`. |
| **`kubeadm: comando no hace nada`** | Binario corrupto vacío en disco. | Se ejecutó: `dnf reinstall -y kubelet kubeadm kubectl --disableexcludes=kubernetes`, recuperando el archivo a su peso real (57 MB). |
| **`crictl: Violación de segmento`** | Binario `/usr/bin/crictl` dañado con cabeceras incompletas (*missing section headers*). | Se ejecutó: `dnf reinstall -y cri-tools --disableexcludes=kubernetes`, restaurando la versión `v1.31.1`. |
| **`no space left on device` al bajar imágenes** | La partición `/var` se creó de solo 960 MB y se llenó al 93%. | Se limpió caché de podman/dnf y se creó un enlace simbólico de `/var/lib/containerd` hacia `/container-data` en la partición raíz `/` (con 12 GB libres). |
| **SSH Timeout con Adaptador Puente** | Aislamiento de clientes en la red inalámbrica física. | Cambio de topología a dos adaptadores (NAT + Host-Only). |

---

## 7. Inicialización del Control Plane (Master)

En el nodo Master se ejecuta `kubeadm init` indicando la IP privada del adaptador Host-Only y la subred para la red de Pods:

```bash
kubeadm init --apiserver-advertise-address=192.168.56.102 --pod-network-cidr=10.244.0.0/16
```

### Configuración del cliente kubectl (en Master):
```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 8. Despliegue de la Red de Pods (CNI - Flannel)

Sin un plugin de red (CNI), los nodos permanecen en estado `NotReady`. En el Master se aplica el manifiesto oficial de Flannel:

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

---

## 9. Unión del Nodo Worker al Clúster

Al finalizar `kubeadm init`, el comando de unión generado se ejecuta en el **Worker**:

```bash
kubeadm join 192.168.56.102:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>
```

> **Nota:** Si se pierde el token, se puede regenerar en el Master con:
> ```bash
> kubeadm token create --print-join-command
> ```

---

## 10. Comandos de Verificación y Evidencias

Comandos para validar ante el profesor que la infraestructura está operativa:

### 1. Estado de los Nodos del Clúster (Ejecutar en Master):
```bash
kubectl get nodes -o wide
```
*(Ambos nodos deben figurar en estado `Ready`).*

### 2. Estado de los Pods del Sistema (Ejecutar en Master):
```bash
kubectl get pods -n kube-system
```
*(Todos los pods: CoreDNS, etcd, flannel, kube-apiserver, kube-proxy, kube-scheduler deben estar en `Running`).*

---

## 📝 Bitácora de Progreso y Comandos Ejecutados
* [x] Documento base creado.
* [x] Crear VM Worker y asegurar conectividad (`192.168.56.x` con Host-Only y ping al 100%).
* [x] Ejecutar prerrequisitos en Master y Worker con Ansible (`ok=19, changed=1, failed=0`).
* [x] `kubeadm init` en Master con IP `192.168.56.102` y red pod `10.244.0.0/16`.
* [x] Despliegue del plugin de red CNI Flannel.
* [x] `kubeadm join` en Worker exitoso (`This node has joined the cluster`).
* [x] Verificación final de los dos nodos registrados (`k8s-master` y `k8s-worker1`).


### 3. Verificación de Memoria Swap Apagada:
```bash
free -m
swapon --show
```

### 4. Verificación de SELinux en Permisivo:
```bash
getenforce
```

### 5. Verificación de Parámetros de Red del Kernel:
```bash
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
```
*(Ambos deben retornar `1`).*
