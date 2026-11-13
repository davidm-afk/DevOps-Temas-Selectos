#!/bin/bash
export KUBECONFIG=/root/.kube/config

echo "=== 1. CLUSTER & NODES ==="
kubectl get nodes -o wide
echo ""

echo "=== 2. COMPONENTES DEL SISTEMA ==="
kubectl get pods -n kube-system
echo ""
kubectl get pods -n kube-flannel
echo ""

echo "=== 3. RECURSOS DEL NAMESPACE mi-app ==="
kubectl get all,sa,configmap,secret -n mi-app -o wide
echo ""

echo "=== 4. AUDITORIA DE POD (ENV Y SECRET INYECTADO) ==="
POD=$(kubectl get pods -n mi-app -l app=mi-app -o jsonpath='{.items[0].metadata.name}')
echo "Auditando Pod: $POD"
kubectl exec -n mi-app $POD -- env | grep -E 'APP_ENV|API_KEY'
echo ""

echo "=== 5. CONTENIDO MONTADO DESDE CONFIGMAP ==="
kubectl exec -n mi-app $POD -- cat /usr/share/nginx/html/index.html
echo ""

echo "=== 6. PRUEBA DE CONECTIVIDAD AL SERVICIO NODEPORT (30090) ==="
curl -i http://127.0.0.1:30090
echo ""

echo "=== 7. PRUEBA DE AUTO-RECUPERACION (SELF-HEALING) ==="
echo "Eliminando pod: $POD..."
kubectl delete pod $POD -n mi-app
sleep 3
kubectl get pods -n mi-app
echo ""

echo "=== 8. PRUEBA DE ESCALABILIDAD (RETO: ESCALADO DINAMICO) ==="
kubectl scale deployment mi-app-deployment --replicas=5 -n mi-app
kubectl rollout status deployment/mi-app-deployment -n mi-app --timeout=60s
kubectl get pods -n mi-app -o wide
echo ""

echo "=== 9. REVERSION DE ESCALA A 3 REPLICAS ==="
kubectl scale deployment mi-app-deployment --replicas=3 -n mi-app
kubectl rollout status deployment/mi-app-deployment -n mi-app --timeout=60s
kubectl get pods -n mi-app -o wide

