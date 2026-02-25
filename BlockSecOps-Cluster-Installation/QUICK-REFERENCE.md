# BlockSecOps Quick Reference Card

## Installation Order (Copy-Paste Commands)

### Phase 1-2: Cluster & Metrics
```bash
minikube start --cpus=8 --memory=11500
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/metrics-server/
```

### Phase 3: Databases
```bash
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/postgresql/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n postgresql-local --timeout=180s

kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/redis/
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=redis -n redis-local --timeout=120s
```

### Phase 4: Security
```bash
# Vault
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/vault/
kubectl wait --for=condition=ready pod/vault-0 -n vault-local --timeout=120s
/Users/pwner/Git/ABS/scripts/init-vault-local.sh

# External Secrets
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/external-secrets/

# Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.crds.yaml
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/cert-manager/
```

### Phase 5: Networking
```bash
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/traefik/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/network-policies/
```

### Phase 6: Harbor Registry
```bash
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/harbor/
kubectl wait --for=condition=ready pod -l app=harbor -n harbor-local --timeout=300s

# Start Harbor proxy
docker run -d --name harbor-proxy --restart always \
  --network minikube -p 5443:5443 alpine/socat:latest \
  TCP-LISTEN:5443,fork,reuseaddr TCP:$(minikube ip):30443
```

### Phase 7: Monitoring
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring-local --create-namespace \
  -f /Users/pwner/Git/ABS/blocksecops-gcp-infrastructure/k8s/overlays/local/monitoring/values.yaml
```

### Phase 8: Application Services
```bash
# Build images (run in minikube docker context)
eval $(minikube docker-env)
cd /Users/pwner/Git/ABS/blocksecops-api-service && docker build -t api-service:latest .
cd /Users/pwner/Git/ABS/blocksecops-dashboard && docker build -t blocksecops-dashboard:latest -f Dockerfile ..
cd /Users/pwner/Git/ABS/blocksecops-orchestration && docker build -t blocksecops-orchestration:latest .
cd /Users/pwner/Git/ABS/blocksecops-tool-integration && docker build -t tool-integration:latest .
cd /Users/pwner/Git/ABS/blocksecops-intelligence-engine && docker build -t intelligence-engine:latest .
cd /Users/pwner/Git/ABS/blocksecops-data-service && docker build -t data-service:latest .
cd /Users/pwner/Git/ABS/blocksecops-notification && docker build -t notification:latest .

# Deploy services
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-dashboard/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-orchestration/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-tool-integration/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-intelligence-engine/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-data-service/k8s/overlays/local/
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-notification/k8s/overlays/local/

# Run migrations
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security" alembic upgrade head
pkill -f "port-forward.*postgresql"
```

### Phase 9: Scanners
```bash
eval $(minikube docker-env)
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images
./build-all.sh
```

### Phase 10: Port Forwards & Verify
```bash
# Start port forwards
kubectl port-forward -n traefik-local svc/traefik 3000:80 &
kubectl port-forward -n monitoring-local svc/kube-prometheus-stack-grafana 3001:80 &
kubectl port-forward -n notification-local svc/notification 8003:8003 &
kubectl port-forward -n harbor-local svc/harbor 8443:443 &

# Verify
curl http://127.0.0.1:3000/api/v1/health/ready
```

---

## Daily Operations

### Start Day
```bash
minikube start
kubectl get pods -A -w  # Wait for all pods
/Users/pwner/Git/ABS/scripts/init-vault-local.sh
/Users/pwner/Git/ABS/scripts/start-port-forwards.sh
curl http://127.0.0.1:3000/api/v1/health/ready
```

### End Day
```bash
pkill -f "kubectl port-forward"
minikube stop
```

### Restart Service
```bash
kubectl rollout restart deployment/<service> -n <service>-local
kubectl rollout status deployment/<service> -n <service>-local
```

---

## Access URLs

| Service | URL |
|---------|-----|
| Dashboard | http://127.0.0.1:3000 |
| API Docs | http://127.0.0.1:3000/api/v1/docs |
| Grafana | http://127.0.0.1:3001 (admin/admin) |
| Harbor | https://127.0.0.1:8443 (admin/Harbor12345) |

---

## Namespace Reference

| Service | Namespace |
|---------|-----------|
| PostgreSQL | postgresql-local |
| Redis | redis-local |
| Vault | vault-local |
| External Secrets | external-secrets-local |
| Cert-Manager | cert-manager-local |
| Traefik | traefik-local |
| Harbor | harbor-local |
| Monitoring | monitoring-local |
| API Service | api-service-local |
| Dashboard | dashboard-local |
| Orchestration | orchestration-local |
| Tool Integration | tool-integration-local |
| Intelligence Engine | intelligence-engine-local |
| Data Service | data-service-local |
| Notification | notification-local |

---

## Troubleshooting Commands

```bash
# Check all pods
kubectl get pods -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check service endpoints
kubectl get endpoints -A | grep -v kube-system

# Check external secrets
kubectl get externalsecrets -A

# Service logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service> --tail=100

# Pod describe
kubectl describe pod -n <namespace> <pod-name>

# Restart all services
for ns in api-service-local dashboard-local orchestration-local tool-integration-local intelligence-engine-local data-service-local notification-local; do
  kubectl rollout restart deployment -n $ns
done
```

---

**Last Updated:** December 13, 2025
