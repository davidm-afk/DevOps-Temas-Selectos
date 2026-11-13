# Resumen de Comandos — Clase 7: Kubernetes Prerrequisitos

> Referencia rápida de comandos para preparar un nodo Rocky Linux para Kubernetes.

---

## Verificación de Prerrequisitos

```bash
# Swap apagada
swapon --show
free -m

# SELinux
getenforce                                    # → Permissive
cat /etc/selinux/config | grep SELINUX=

# Módulos del Kernel
lsmod | grep -E "overlay|br_netfilter"
cat /etc/modules-load.d/k8s.conf

# Parámetros sysctl
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
cat /etc/sysctl.d/k8s.conf

# Firewall
systemctl is-active firewalld                 # → inactive

# containerd
systemctl is-active containerd                # → active
systemctl status containerd --no-pager
containerd --version

# Kubernetes tools
kubeadm version --output=short               # → v1.31.14
kubectl version --client --short
kubelet --version
```

## Ejecutar el Playbook de Prerrequisitos

```bash
cd /root/devops2026/ansible
ansible-playbook k8s_prerequisitos.yml --syntax-check
ansible-playbook k8s_prerequisitos.yml         # 1ª corrida: changed=14
ansible-playbook k8s_prerequisitos.yml         # 2ª corrida: changed=1 (idempotente)
```

## Inicializar el Clúster (siguiente clase)

```bash
# Control Plane
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurar kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# CNI: Flannel
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Nodo single (Control Plane actúa también como Worker)
kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# Verificar
kubectl get nodes
kubectl get pods -A
```

## kubectl Cheatsheet

```bash
kubectl get nodes                             # Estado de nodos
kubectl get pods -A                           # Pods en todos los namespaces
kubectl get pods -n kube-system               # Pods del sistema
kubectl describe node <nombre>                # Detalles del nodo
kubectl describe pod <nombre> -n <ns>         # Detalles de un Pod
kubectl apply -f <manifiesto>.yaml            # Crear/actualizar recurso
kubectl delete -f <manifiesto>.yaml           # Eliminar recurso
kubectl logs <pod> -n <ns>                    # Logs de un Pod
kubectl exec -it <pod> -- bash                # Shell en un Pod
kubectl get events -n <ns> --sort-by='.lastTimestamp'
```

