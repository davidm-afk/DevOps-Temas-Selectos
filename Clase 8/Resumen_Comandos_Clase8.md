# Resumen de Comandos — Clase 8: Kubernetes Clúster Multi-Nodo

> Referencia rápida de todos los comandos de la Clase 8

---

## 🔧 Setup Inicial del Clúster

```bash
# Configurar hostname e /etc/hosts (en cada nodo)
hostnamectl set-hostname k8s-master       # o k8s-worker1
echo "192.168.71.128  k8s-master" >> /etc/hosts
echo "192.168.71.X    k8s-worker1" >> /etc/hosts

# Inicializar Control Plane (solo en master)
kubeadm init --apiserver-advertise-address=192.168.71.128 --pod-network-cidr=10.244.0.0/16

# Configurar kubectl (en master, como root)
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Instalar CNI Flannel (en master)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Unir worker al clúster (en worker)
kubeadm join 192.168.71.128:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>

# Regenerar token si expiró (en master)
kubeadm token create --print-join-command
```

---

## 🔍 Verificación del Clúster

```bash
kubectl get nodes -o wide             # Estado de todos los nodos
kubectl get pods -A                   # Todos los pods en todos los namespaces
kubectl get pods -n kube-system       # Pods del sistema K8s
kubectl get pods -n kube-flannel      # Pods de red CNI
kubectl cluster-info                  # Info del API Server
```

---

## 📦 Namespaces

```bash
kubectl create namespace dev
kubectl apply -f namespace.yaml
kubectl get namespaces
kubectl config set-context --current --namespace=bootcamp
kubectl delete namespace dev
```

---

## 🐳 Pods

```bash
kubectl apply -f pod.yaml
kubectl get pods -o wide
kubectl describe pod <nombre>
kubectl logs <nombre>
kubectl logs <nombre> -c <contenedor>    # Pod multi-contenedor
kubectl exec -it <nombre> -- bash
kubectl delete pod <nombre>
kubectl port-forward pod/<nombre> 8080:80
```

---

## 🗺️ ConfigMaps

```bash
kubectl apply -f configmap.yaml
kubectl get configmap <nombre>
kubectl get configmap <nombre> -o yaml
kubectl describe configmap <nombre>
# Hot reload (en volumen): verificar sin reiniciar
kubectl exec <pod> -- cat /etc/config/app.properties
```

---

## 🔐 Secrets

```bash
kubectl apply -f secret.yaml
kubectl get secret <nombre> -o yaml
# Decodificar base64:
echo "<valor_base64>" | base64 --decode
# Verificar inyección en pod:
kubectl exec <pod> -- env | grep API_KEY
```

---

## 👤 RBAC y ServiceAccount

```bash
kubectl apply -f rbac.yaml
kubectl get serviceaccounts
kubectl auth can-i list pods --as=system:serviceaccount:<ns>:<sa-name> -n <ns>
kubectl auth can-i delete pods --as=system:serviceaccount:<ns>:<sa-name> -n <ns>
```

---

## 🚀 Deployments

```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl get pods -o wide                           # Ver distribución en nodos

# Escalado:
kubectl scale deployment <nombre> --replicas=5

# Rolling Update:
kubectl set image deployment/<nombre> <container>=<image>:<tag>
kubectl rollout status deployment/<nombre>
kubectl rollout history deployment/<nombre>
kubectl rollout undo deployment/<nombre>
kubectl rollout undo deployment/<nombre> --to-revision=1

# Self-healing (eliminar pod para ver auto-recuperación):
kubectl delete pod <nombre-pod>
kubectl get pods    # Deployment recrea el pod automáticamente
```

---

## 🌐 Services

```bash
kubectl apply -f service.yaml
kubectl get services -n <namespace>
kubectl get endpoints <service> -n <namespace>

# Acceder a NodePort:
curl http://192.168.71.128:30090

# Port-forward temporal:
kubectl port-forward service/<nombre> 8080:80
```

---

## 🔄 Ejercicio Integrador

```bash
kubectl apply -f todo-en-uno.yaml
kubectl get all -n mi-app -o wide
kubectl rollout status deployment/mi-app-deployment -n mi-app

POD=$(kubectl get pods -n mi-app -l app=mi-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mi-app $POD -- env | grep -E 'APP_ENV|API_KEY'
kubectl exec -n mi-app $POD -- cat /usr/share/nginx/html/index.html
kubectl delete pod $POD -n mi-app                            # Test self-healing
kubectl scale deployment mi-app-deployment --replicas=5 -n mi-app
curl http://192.168.71.128:30090
```

---

## 🛠️ Troubleshooting

```bash
# Reparar binarios corruptos:
dnf reinstall -y kubelet kubeadm kubectl cri-tools --disableexcludes=kubernetes

# Limpiar caché DNF/containerd:
dnf clean all
rm -rf /var/cache/dnf

# Ver logs de kubelet:
journalctl -u kubelet -n 50 --no-pager

# Ver logs de containerd:
journalctl -u containerd -n 30 --no-pager

# Reset completo del nodo (cuidado — destructivo):
kubeadm reset
```

---

## 🔢 Versiones

```bash
kubeadm version
kubectl version --client
kubelet --version
containerd --version
crictl version
```

