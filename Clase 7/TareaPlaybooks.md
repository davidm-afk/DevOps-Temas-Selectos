# 🚀 Tarea: Playbook de Ansible para Prerrequisitos de Kubernetes en RHEL 9 / Rocky Linux 9

Guía basada en el tutorial: [Kubernetes Installation on RHEL 9 (weeklycloud)](https://medium.com/weeklycloud/kubernetes-installation-on-rhel-9-d5629f2fa4f9)

---

## 📌 ¿De qué trata esta tarea?

Antes de que Kubernetes pueda arrancar su clúster (`kubeadm init`), el sistema operativo necesita estar "afinado" y preparado. Si intentas instalarlo en un Linux recién salido de la caja, el instalador va a chillar y abortar.

Este playbook automatiza **todos los prerrequisitos del sistema** usando **Ansible** de forma **declarativa e idempotente** (si lo corres 1 o 10 veces, deja la máquina en el estado exacto sin romper nada).

---

## 🧠 ¿Qué prerrequisitos pide Kubernetes y por qué?

1. **Desactivar la memoria Swap:**  
   * **Por qué:** El planificador de Kubernetes (`kubelet`) necesita saber con exactitud cuánta memoria física real tiene cada contenedor. Si el kernel empieza a mandar memoria a swap en disco, el rendimiento se desploma y se rompe la garantía de recursos de los Pods.
2. **Poner SELinux en modo Permisivo (`permissive`):**  
   * **Por qué:** Las políticas por defecto de SELinux en RHEL 9 bloquean el acceso de los contenedores a los sistemas de archivos del host y redes compartidas. Se pone en permisivo para registrar advertencias sin bloquear las operaciones de Kubernetes.
3. **Deshabilitar o configurar el Firewall (`firewalld`):**  
   * **Por qué:** En entornos de laboratorio, las reglas de `firewalld` suelen bloquear el tráfico interno entre Pods y los puertos críticos del API Server (`6443`) y etcd (`2379-2380`).
4. **Módulos del Kernel (`overlay` y `br_netfilter`):**  
   * **Por qué:** 
     * `overlay`: Necesario para el sistema de capas de almacenamiento de los contenedores (OverlayFS).
     * `br_netfilter`: Permite que los paquetes de red que cruzan los puentes virtuales (bridges) de Linux sean procesados por iptables para el filtrado y enrutamiento de los Pods.
5. **Parámetros Sysctl de Red (`net.bridge.bridge-nf-call-iptables`, `ip_forward`):**  
   * **Por qué:** Permite que el tráfico entre Pods pase correctamente a través del kernel y que los nodos puedan reenviar paquetes IPv4 entre interfaces.
6. **Instalar el Runtime de Contenedores (`containerd`):**  
   * **Por qué:** Desde la versión 1.24, Kubernetes ya no usa Docker directamente; usa un runtime ligero compatible con CRI (*Container Runtime Interface*). Configuramos `containerd` con el controlador de grupos de control de systemd (`SystemdCgroup = true`).
7. **Instalar las herramientas oficiales de Kubernetes:**  
   * **Por qué:** Añadir el repositorio oficial `pkgs.k8s.io` e instalar el trío fundamental:
     * `kubeadm`: La herramienta para inicializar el clúster.
     * `kubelet`: El agente del nodo que corre en segundo plano.
     * `kubectl`: La herramienta de línea de comandos para administrarlo.

---

## 🛠️ El Playbook Completo: `k8s_prerequisitos.yml`

Guarda este archivo en tu máquina virtual dentro de `/root/devops2026/ansible/k8s_prerequisitos.yml`:

```yaml
---
- name: Preparar nodo RHEL 9 / Rocky Linux 9 para Kubernetes
  hosts: web
  become: true
  vars:
    k8s_version: "v1.31"

  tasks:
    # =========================================================================
    # 1. GESTIÓN DE SWAP
    # =========================================================================
    - name: 1.1 Desactivar Swap temporalmente en memoria
      ansible.builtin.command: swapoff -a
      when: ansible_swaptotal_mb > 0
      changed_when: true

    - name: 1.2 Comentar la línea de Swap en /etc/fstab para que sea permanente
      ansible.builtin.replace:
        path: /etc/fstab
        regexp: '^(\s*[^#\s]+\s+[^#\s]+\s+swap\s+.*)$'
        replace: '# \1'

    # =========================================================================
    # 2. CONFIGURACIÓN DE SELINUX
    # =========================================================================
    - name: 2.1 Configurar SELinux en modo permissive de forma persistente
      ansible.builtin.lineinfile:
        path: /etc/selinux/config
        regexp: '^SELINUX='
        line: 'SELINUX=permissive'

    - name: 2.2 Poner SELinux en modo permissive de inmediato
      ansible.builtin.command: setenforce 0
      register: setenforce_result
      failed_when: false
      changed_when: setenforce_result.rc == 0

    # =========================================================================
    # 3. GESTIÓN DE FIREWALL
    # =========================================================================
    - name: 3.1 Detener y deshabilitar firewalld para evitar bloqueos en el laboratorio
      ansible.builtin.service:
        name: firewalld
        state: stopped
        enabled: false
      failed_when: false

    # =========================================================================
    # 4. MÓDULOS DEL KERNEL
    # =========================================================================
    - name: 4.1 Configurar carga automática de módulos overlay y br_netfilter
      ansible.builtin.copy:
        dest: /etc/modules-load.d/k8s.conf
        content: |
          overlay
          br_netfilter
        mode: '0644'

    - name: 4.2 Cargar módulo overlay en el kernel actual
      ansible.builtin.command: modprobe overlay
      changed_when: false

    - name: 4.3 Cargar módulo br_netfilter en el kernel actual
      ansible.builtin.command: modprobe br_netfilter
      changed_when: false

    # =========================================================================
    # 5. PARÁMETROS SYSCTL DE RED
    # =========================================================================
    - name: 5.1 Configurar sysctl para filtrado de red y reenvío IPv4
      ansible.builtin.copy:
        dest: /etc/sysctl.d/k8s.conf
        content: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1
        mode: '0644'
      notify: Aplicar parámetros sysctl

    # =========================================================================
    # 6. RUNTIME DE CONTENEDORES (containerd)
    # =========================================================================
    - name: 6.1 Instalar utilerías básicas de repositorios (dnf-plugins-core)
      ansible.builtin.dnf:
        name:
          - dnf-plugins-core
          - iproute-tc
        state: present

    - name: 6.2 Agregar repositorio de Docker/containerd
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/rhel/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
        mode: '0644'

    - name: 6.3 Instalar containerd.io
      ansible.builtin.dnf:
        name: containerd.io
        state: present

    - name: 6.4 Crear directorio de configuración para containerd
      ansible.builtin.file:
        path: /etc/containerd
        state: directory
        mode: '0755'

    - name: 6.5 Generar configuración por defecto de containerd si no existe
      ansible.builtin.shell: containerd config default > /etc/containerd/config.toml
      args:
        creates: /etc/containerd/config.toml
      notify: Reiniciar containerd

    - name: 6.6 Habilitar SystemdCgroup en la configuración de containerd
      ansible.builtin.replace:
        path: /etc/containerd/config.toml
        regexp: 'SystemdCgroup = false'
        replace: 'SystemdCgroup = true'
      notify: Reiniciar containerd

    - name: 6.7 Iniciar y habilitar servicio containerd
      ansible.builtin.service:
        name: containerd
        state: started
        enabled: true

    # =========================================================================
    # 7. HERRAMIENTAS DE KUBERNETES (kubelet, kubeadm, kubectl)
    # =========================================================================
    - name: 7.1 Configurar el repositorio oficial de Kubernetes (pkgs.k8s.io)
      ansible.builtin.copy:
        dest: /etc/yum.repos.d/kubernetes.repo
        content: |
          [kubernetes]
          name=Kubernetes
          baseurl=https://pkgs.k8s.io/core:/stable:/{{ k8s_version }}/rpm/
          enabled=1
          gpgcheck=1
          gpgkey=https://pkgs.k8s.io/core:/stable:/{{ k8s_version }}/rpm/repodata/repomd.xml.key
        mode: '0644'

    - name: 7.2 Instalar kubelet, kubeadm y kubectl
      ansible.builtin.dnf:
        name:
          - kubelet
          - kubeadm
          - kubectl
        state: present
        disable_excludes: kubernetes

    - name: 7.3 Habilitar el servicio kubelet en el arranque del sistema
      ansible.builtin.service:
        name: kubelet
        enabled: true

  # ===========================================================================
  # HANDLERS (solo corren si hubo cambios reales)
  # ===========================================================================
  handlers:
    - name: Aplicar parámetros sysctl
      ansible.builtin.command: sysctl --system

    - name: Reiniciar containerd
      ansible.builtin.service:
        name: containerd
        state: restarted
```

---

## 📋 Paso a Paso para Ejecutarlo en tu VM

Sigue estos sencillos pasos desde tu sesión SSH conectada a la máquina virtual:

### Paso 1: Ir a la carpeta del proyecto Ansible
```bash
cd /root/devops2026/ansible
```

### Paso 2: Crear el archivo del Playbook
Copia y pega este comando en tu terminal para crear el archivo `k8s_prerequisitos.yml`:

```bash
cat << 'EOF' > k8s_prerequisitos.yml
---
- name: Preparar nodo RHEL 9 / Rocky Linux 9 para Kubernetes
  hosts: web
  become: true
  vars:
    k8s_version: "v1.31"

  tasks:
    - name: 1.1 Desactivar Swap temporalmente en memoria
      ansible.builtin.command: swapoff -a
      when: ansible_swaptotal_mb > 0
      changed_when: true

    - name: 1.2 Comentar la línea de Swap en /etc/fstab para que sea permanente
      ansible.builtin.replace:
        path: /etc/fstab
        regexp: '^(\s*[^#\s]+\s+[^#\s]+\s+swap\s+.*)$'
        replace: '# \1'

    - name: 2.1 Configurar SELinux en modo permissive de forma persistente
      ansible.builtin.lineinfile:
        path: /etc/selinux/config
        regexp: '^SELINUX='
        line: 'SELINUX=permissive'

    - name: 2.2 Poner SELinux en modo permissive de inmediato
      ansible.builtin.command: setenforce 0
      register: setenforce_result
      failed_when: false
      changed_when: setenforce_result.rc == 0

    - name: 3.1 Detener y deshabilitar firewalld para evitar bloqueos en el laboratorio
      ansible.builtin.service:
        name: firewalld
        state: stopped
        enabled: false
      failed_when: false

    - name: 4.1 Configurar carga automática de módulos overlay y br_netfilter
      ansible.builtin.copy:
        dest: /etc/modules-load.d/k8s.conf
        content: |
          overlay
          br_netfilter
        mode: '0644'

    - name: 4.2 Cargar módulo overlay en el kernel actual
      ansible.builtin.command: modprobe overlay
      changed_when: false

    - name: 4.3 Cargar módulo br_netfilter en el kernel actual
      ansible.builtin.command: modprobe br_netfilter
      changed_when: false

    - name: 5.1 Configurar sysctl para filtrado de red y reenvío IPv4
      ansible.builtin.copy:
        dest: /etc/sysctl.d/k8s.conf
        content: |
          net.bridge.bridge-nf-call-iptables  = 1
          net.bridge.bridge-nf-call-ip6tables = 1
          net.ipv4.ip_forward                 = 1
        mode: '0644'
      notify: Aplicar parámetros sysctl

    - name: 6.1 Instalar utilerías básicas de repositorios (dnf-plugins-core)
      ansible.builtin.dnf:
        name:
          - dnf-plugins-core
          - iproute-tc
        state: present

    - name: 6.2 Agregar repositorio de Docker/containerd
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/rhel/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo
        mode: '0644'

    - name: 6.3 Instalar containerd.io
      ansible.builtin.dnf:
        name: containerd.io
        state: present

    - name: 6.4 Crear directorio de configuración para containerd
      ansible.builtin.file:
        path: /etc/containerd
        state: directory
        mode: '0755'

    - name: 6.5 Generar configuración por defecto de containerd si no existe
      ansible.builtin.shell: containerd config default > /etc/containerd/config.toml
      args:
        creates: /etc/containerd/config.toml
      notify: Reiniciar containerd

    - name: 6.6 Habilitar SystemdCgroup en la configuración de containerd
      ansible.builtin.replace:
        path: /etc/containerd/config.toml
        regexp: 'SystemdCgroup = false'
        replace: 'SystemdCgroup = true'
      notify: Reiniciar containerd

    - name: 6.7 Iniciar y habilitar servicio containerd
      ansible.builtin.service:
        name: containerd
        state: started
        enabled: true

    - name: 7.1 Configurar el repositorio oficial de Kubernetes (pkgs.k8s.io)
      ansible.builtin.copy:
        dest: /etc/yum.repos.d/kubernetes.repo
        content: |
          [kubernetes]
          name=Kubernetes
          baseurl=https://pkgs.k8s.io/core:/stable:/{{ k8s_version }}/rpm/
          enabled=1
          gpgcheck=1
          gpgkey=https://pkgs.k8s.io/core:/stable:/{{ k8s_version }}/rpm/repodata/repomd.xml.key
        mode: '0644'

    - name: 7.2 Instalar kubelet, kubeadm y kubectl
      ansible.builtin.dnf:
        name:
          - kubelet
          - kubeadm
          - kubectl
        state: present
        disable_excludes: kubernetes

    - name: 7.3 Habilitar el servicio kubelet en el arranque del sistema
      ansible.builtin.service:
        name: kubelet
        enabled: true

  handlers:
    - name: Aplicar parámetros sysctl
      ansible.builtin.command: sysctl --system

    - name: Reiniciar containerd
      ansible.builtin.service:
        name: containerd
        state: restarted
EOF
```

### Paso 3: Validar la sintaxis del Playbook
```bash
ansible-playbook k8s_prerequisitos.yml --syntax-check
```
> Si no hay errores, devolverá: `playbook: k8s_prerequisitos.yml`.

### Paso 4: Ejecutar el Playbook
```bash
ansible-playbook k8s_prerequisitos.yml
```

### Paso 5: Probar la Idempotencia (2da corrida)
Vuelve a ejecutarlo para tu evidencia de clase:
```bash
ansible-playbook k8s_prerequisitos.yml
```
> Verás que en el `PLAY RECAP` casi todo es `ok` y prácticamente no hay `changed`, demostrando que el estado deseado ya fue alcanzado.

---

## 🔍 Comandos de Verificación (Evidencias)

Para demostrarle a tu profesor que todo quedó al 100%, ejecuta estos comandos en tu VM:

1. **Verificar que la Swap está apagada:**
   ```bash
   swapon --show
   free -m
   ```

2. **Verificar el modo de SELinux:**
   ```bash
   getenforce
   ```
   *(Debe responder: `Permissive`).*

3. **Verificar los módulos del kernel cargados:**
   ```bash
   lsmod | grep -E "overlay|br_netfilter"
   ```

4. **Verificar los parámetros de red sysctl:**
   ```bash
   sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
   ```

5. **Verificar containerd activo y corriendo:**
   ```bash
   systemctl status containerd --no-pager
   ```

6. **Verificar las herramientas de Kubernetes instaladas:**
   ```bash
   kubeadm version
   kubectl version --client
   kubelet --version
   ```
