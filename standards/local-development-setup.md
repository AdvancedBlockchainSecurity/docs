# Local Development Setup Standards

**Version:** 2.1.0
**Last Updated:** November 30, 2025
**Status:** Active

> **Major Update (v2.1.0):** Added Production Parity Principle. All traffic MUST go through Traefik ingress controller. Port-forward to Traefik, NOT directly to services.

## Production Parity Principle

**CRITICAL REQUIREMENT:** Local development MUST replicate production routing and architecture.

| Aspect | Local Environment | Production Environment | Parity Required |
|--------|-------------------|------------------------|-----------------|
| Ingress Controller | Traefik v3.6+ | Traefik v3.6+ | **YES** |
| API Routing | Traefik routes `/api/*` to API service | Traefik routes `/api/*` to API service | **YES** |
| Single Entry Point | All traffic through Traefik on port 3000 | All traffic through ingress | **YES** |
| Container Runtime | Minikube Docker | AWS EKS | Similar |
| TLS/SSL | Self-signed (optional) | cert-manager | Acceptable deviation |

### Why Production Parity Matters

- **Test real routing**: API routing through Traefik is tested locally the same way it works in production
- **Single entry point**: All traffic goes through Traefik, just like production
- **Consistent debugging**: Routing issues are caught during local development, not after deployment

### Deviation Notification Requirement

**If production parity cannot be achieved for any reason:**
1. **STOP** - Do not proceed with a non-production-like solution
2. **DOCUMENT** - Create an issue describing the deviation
3. **NOTIFY** - Alert the team lead before implementing
4. **DECIDE** - Wait for approval on how to proceed

This ensures we catch production issues during local development, not after deployment.

## Minikube Configuration

**MANDATORY resource requirements for local Kubernetes cluster:**

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| Memory | 8GB | 10GB | Required for all platform services |
| CPU Cores | 4 | 6 | More cores improve build performance |
| Disk | 40GB | 60GB | For container images and volumes |

### Initial Setup

```bash
# Configure minikube with required resources
minikube config set memory 10240
minikube config set cpus 6

# Start minikube (first time)
minikube start --memory=10240 --cpus=6

# Verify configuration
minikube config view
```

### Important Notes

1. **Resource changes require cluster recreation:**
   ```bash
   # Cannot change resources on existing cluster
   minikube stop
   minikube delete
   minikube start --memory=10240 --cpus=6
   ```

2. **Docker Desktop memory limit:** Ensure Docker Desktop has at least 10GB allocated in Settings → Resources → Advanced. Minikube cannot exceed Docker Desktop's memory allocation.

3. **Verify resources after start:**
   ```bash
   kubectl top nodes
   # Should show ~10GB allocatable memory
   ```

### Troubleshooting Resource Issues

**Symptom:** Pods stuck in `Pending` state with "Insufficient memory" events

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace> | tail -20

# Check node allocatable vs requested resources
kubectl describe node minikube | grep -A 10 "Allocated resources"
```

**Fix:** Either increase minikube resources (requires cluster recreation) or scale down non-essential services:

```bash
# Scale down non-essential services to free memory
kubectl scale deployment notification -n notification-local --replicas=1
kubectl scale deployment data-service -n data-service-local --replicas=1
```

### Clean Up Stale Resources

Old failed pods consume memory allocations. Clean them periodically:

```bash
# Delete failed pods from tool-integration namespace
kubectl delete pods -n tool-integration-local --field-selector=status.phase=Failed

# Delete old job pods
kubectl delete pods -n tool-integration-local -l job-name --field-selector=status.phase!=Running
```

## Access Endpoints

> **IMPORTANT:** With the Traefik migration, the dashboard and API are accessed via a single Traefik ingress on port 3000. See [Dashboard Development Standards](./dashboard-development.md) for the correct startup procedure.

**MANDATORY endpoints for local development:**

| Service | Endpoint | Notes |
|---------|----------|-------|
| Dashboard | `http://127.0.0.1:3000` | Main dashboard (via Traefik ingress) |
| API Service | `http://127.0.0.1:3000/api/v1` | FastAPI backend (via Traefik routing) |
| API Docs | `http://127.0.0.1:3000/api/v1/docs` | Swagger UI (via Traefik) |
| Notification | `http://127.0.0.1:8003` | WebSocket server (direct port-forward) |
| Grafana | `http://127.0.0.1:3001` | Monitoring dashboard |
| Prometheus | `http://127.0.0.1:9090` | Metrics (when forwarded) |
| PostgreSQL | `127.0.0.1:5432` | Database (direct port-forward, optional) |
| Redis | `127.0.0.1:6379` | Cache (direct port-forward, optional) |

## Port Forward Standards

> **📖 Comprehensive Documentation:** See [Port-Forwarding Standards](./port-forwarding.md) for complete port mapping tables, troubleshooting guides, and best practices for all platform services.

**Standard port-forward script** (save as `scripts/port-forward-local.sh`):

```bash
#!/bin/bash
# Port forward all local development services
# IMPORTANT: Dashboard and API are accessed via Traefik on port 3000
# See dashboard-development.md for the correct startup procedure

echo "Starting port forwards for local development..."

# Kill existing port forwards
pkill -f "kubectl port-forward" 2>/dev/null
sleep 2

# PRIMARY: Traefik Ingress (routes to dashboard AND API)
kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &
echo "✅ Traefik (Dashboard + API): http://127.0.0.1:3000"

# Optional: Direct database access for debugging
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 > /tmp/pf-postgresql.log 2>&1 &
echo "✅ PostgreSQL: 127.0.0.1:5432"

kubectl port-forward -n redis-local svc/redis 6379:6379 > /tmp/pf-redis.log 2>&1 &
echo "✅ Redis: 127.0.0.1:6379"

# Notification Service (WebSocket)
kubectl port-forward -n notification-local svc/notification 8003:8003 > /tmp/pf-notification.log 2>&1 &
echo "✅ Notification: http://127.0.0.1:8003"

# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80 > /tmp/pf-grafana.log 2>&1 &
echo "✅ Grafana: http://127.0.0.1:3001"

sleep 3
echo ""
echo "All port forwards active. Use 127.0.0.1 for all connections."
echo "Dashboard: http://127.0.0.1:3000"
echo "API Health: http://127.0.0.1:3000/api/v1/health/live"
```

## Port Number Consistency Standards

**CRITICAL:** Never change port numbers without updating all dependent configurations.

**Why this matters:**
- **Platform Consistency:** Changing port numbers breaks integrations across the platform
- **CORS Configuration:** Backend services whitelist specific ports
- **Documentation Accuracy:** All docs reference standard ports
- **Team Coordination:** Other developers expect services on standard ports
- **Testing Scripts:** Automated tests hardcode port numbers

**Standard Port Assignments:**

| Service | Port | Purpose | Notes |
|---------|------|---------|-------|
| Dashboard | 3000 | Main Dashboard UI | Primary user interface with Supabase Auth (blocksecops-dashboard) |
| API Service | 8000 | Backend API | FastAPI application |
| Notification | 8003 | WebSocket | Real-time notifications |
| Grafana | 3001 | Monitoring | Metrics dashboard |
| PostgreSQL | 5432 | Database | Port-forwarded only |
| Redis | 6379 | Cache | Port-forwarded only |

**If a port is occupied:**

```bash
# ❌ INCORRECT: Run services on alternate ports
# This breaks relative URL routing through Traefik

# ✅ CORRECT: Free up the standard port and restart Traefik port-forward
lsof -ti:3000 | xargs kill -9  # Kill process using port 3000
kubectl port-forward -n traefik-local svc/traefik 3000:80 &
```

**When ports conflict during development:**

```bash
# 1. Identify what's using the port
lsof -i:3000

# 2. If it's an old/stale process, kill it
kill -9 <PID>

# 3. If it's a legitimate kubectl port-forward, it may have disconnected
# Kill all port-forwards and restart
pkill -f "kubectl port-forward"

# 4. Restart port-forwards
kubectl port-forward -n traefik-local svc/traefik 3000:80 &
```

> **⚠️ IMPORTANT:** Do NOT run `npm run dev` locally for the dashboard. The dashboard runs inside Minikube and is accessed via Traefik. See [Dashboard Development Standards](./dashboard-development.md).

## Kubernetes Service Selector Standards

**CRITICAL:** Service selectors must match pod labels, or services will have no endpoints.

### The includeSelectors Problem

**Issue:** Kustomize `includeSelectors: true` adds ALL common labels to service selectors, creating mismatches.

**Example of the problem:**

```yaml
# kustomization.yaml with includeSelectors: true
labels:
- includeSelectors: true  # ❌ DANGEROUS
  pairs:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/instance: local-api-service
    app.kubernetes.io/version: 0.3.12
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

**Result:** Service selector gets 8 labels, but deployment only adds 3 labels to pod template:

```yaml
# Service selector (8 labels)
selector:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/instance: local-api-service
  app.kubernetes.io/version: 0.3.12
  app.kubernetes.io/component: backend-api
  app.kubernetes.io/part-of: blocksecops-platform
  app.kubernetes.io/managed-by: kustomize
  environment: local
  team: backend

# Pod labels (only 3 labels)
labels:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: blocksecops-platform
```

**Result:** Service has NO ENDPOINTS because selector doesn't match pods.

```bash
$ kubectl get endpoints -n api-service-local api-service
NAME          ENDPOINTS   AGE
api-service   <none>      10d
```

### The Solution: includeSelectors: false

**MANDATORY:** Always set `includeSelectors: false` in Kustomize overlays.

```yaml
# ✅ CORRECT: includeSelectors: false
labels:
- includeSelectors: false  # Only adds labels to metadata, not selectors
  pairs:
    app.kubernetes.io/name: api-service
    app.kubernetes.io/instance: local-api-service
    app.kubernetes.io/version: 0.3.12
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

**Result:** Service selector uses only the labels defined in base service manifest:

```yaml
# Service selector (minimal, matches pods)
selector:
  app.kubernetes.io/name: api-service

# Pod labels (matches selector)
labels:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/component: backend
  app.kubernetes.io/part-of: blocksecops-platform
```

**Verification:**

```bash
# 1. Check service selector
kubectl get svc -n api-service-local api-service -o jsonpath='{.spec.selector}' | jq .

# 2. Check pod labels
kubectl get pods -n api-service-local -l app.kubernetes.io/name=api-service -o jsonpath='{.items[0].metadata.labels}' | jq .

# 3. Verify service has endpoints
kubectl get endpoints -n api-service-local api-service

# ✅ GOOD: Shows IP addresses and ports
# NAME          ENDPOINTS                           AGE
# api-service   10.244.4.14:9090,10.244.4.14:8000   10d

# ❌ BAD: No endpoints (selector mismatch)
# NAME          ENDPOINTS   AGE
# api-service   <none>      10d
```

### Service Selector Best Practices

**1. Keep selectors minimal** - Only use labels that uniquely identify the pod:

```yaml
# ✅ GOOD: Minimal, specific selector
selector:
  app.kubernetes.io/name: api-service

# ❌ BAD: Too many labels
selector:
  app.kubernetes.io/name: api-service
  app.kubernetes.io/version: 0.3.12  # Version changes with each release!
  environment: local
  team: backend
```

**2. Base service defines selector** - Overlay only patches if absolutely necessary:

```yaml
# base/api-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app.kubernetes.io/name: api-service  # ✅ Simple, stable selector
  ports:
  - name: http
    port: 8000
    targetPort: http
```

**3. Never change selectors in overlays** - Use service-patch.yaml only for ports/annotations:

```yaml
# overlays/local/service-patch.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
  annotations:
    prometheus.io/scrape: "true"
spec:
  type: NodePort
  ports:
  - name: http
    port: 8000
    targetPort: 8000
    nodePort: 30800
  # ✅ NO selector override - uses base service selector
```

### Troubleshooting Service Endpoints

**Symptom:** Service has no endpoints, port-forward fails, API not accessible

**Diagnosis:**

```bash
# 1. Check if service has endpoints
kubectl get endpoints -n <namespace> <service-name>

# 2. If no endpoints, check selector vs pod labels
kubectl get svc -n <namespace> <service-name> -o yaml | grep -A 10 "selector:"
kubectl get pods -n <namespace> -o yaml | grep -A 10 "labels:"

# 3. Check kustomization.yaml for includeSelectors
cat k8s/overlays/local/kustomization.yaml | grep -A 2 "includeSelectors"
```

**Fix:**

```bash
# 1. Update kustomization.yaml
cd /Users/pwner/Git/ABS/blocksecops-<service>/k8s/overlays/local
vim kustomization.yaml

# Change:
# includeSelectors: true
# To:
# includeSelectors: false

# 2. Apply changes
kubectl apply -k .

# 3. Verify endpoints now exist
kubectl get endpoints -n <namespace> <service-name>

# 4. Test connectivity
kubectl port-forward -n <namespace> svc/<service-name> <port>:<port> &
sleep 2
curl http://localhost:<port>/health
```

### Standard Kustomization Pattern

**Use this pattern for ALL service overlays:**

```yaml
# k8s/overlays/local/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- ../../base/

namespace: <service>-local

patches:
- path: deployment-patch.yaml
  target:
    kind: Deployment
    name: <service>
- path: configmap-patch.yaml
  target:
    kind: ConfigMap
    name: <service>-config
- path: service-patch.yaml
  target:
    kind: Service
    name: <service>

images:
- name: PLACEHOLDER_REGISTRY/<service>
  newName: <service>
  newTag: 0.1.0

# ✅ CRITICAL: includeSelectors MUST be false
labels:
- includeSelectors: false  # Never change this to true!
  pairs:
    app.kubernetes.io/name: <service>
    app.kubernetes.io/instance: local-<service>
    app.kubernetes.io/version: 0.1.0
    app.kubernetes.io/component: backend-api
    app.kubernetes.io/part-of: blocksecops-platform
    app.kubernetes.io/managed-by: kustomize
    environment: local
    team: backend
```

## Environment Configuration

> **NOTE:** With the Traefik migration, the dashboard uses **relative URLs** for API calls (`/api/v1`). Traefik routes these requests to the API service. No `VITE_API_BASE_URL` is needed.

**Dashboard environment** (built into container):

The dashboard is built with relative URL configuration and runs inside Minikube. The API client (`src/lib/api/client.ts`) uses:
```typescript
const API_PREFIX = '/api/v1';  // Relative URL - routed by Traefik
```

**WebSocket configuration** (if needed):
```bash
# For WebSocket connections that bypass Traefik
VITE_WS_URL=ws://127.0.0.1:8003
```

**CORS Configuration Template:**

```python
# Location: blocksecops-api-service/src/infrastructure/middleware/cors.py

from fastapi.middleware.cors import CORSMiddleware
from src.config import settings

def configure_cors(app):
    """Configure CORS for all environments."""

    # Base origins (always allowed)
    origins = [
        "http://127.0.0.1:3000",  # Dashboard (blocksecops-dashboard)
        "http://localhost:3000",   # Optional: Compatibility
    ]

    # Add environment-specific origins
    if settings.ENVIRONMENT == "staging":
        origins.append("https://staging.blocksecops.com")
    elif settings.ENVIRONMENT == "production":
        origins.append("https://app.blocksecops.com")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
```

## Local Development Checklist

Before starting development work:

- [ ] Minikube cluster is running with adequate resources (10GB memory, 6 CPUs)
- [ ] All required services deployed and healthy (`kubectl get pods -A`)
- [ ] All services have endpoints: `kubectl get endpoints -A | grep -v kube-system`
- [ ] Traefik port-forward active on 3000: `lsof -i :3000 | grep LISTEN`
- [ ] Dashboard accessible via Traefik: `curl -s http://127.0.0.1:3000 | head -1`
- [ ] API health passing via Traefik: `curl http://127.0.0.1:3000/api/v1/health/ready`
- [ ] **NOT running `npm run dev` locally** (dashboard runs inside Minikube!)
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] Can access API docs at `http://127.0.0.1:3000/api/v1/docs`
- [ ] No console errors in browser (F12 → Console tab)

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Dashboard Development](./dashboard-development.md) - Dashboard-specific setup and workflows
- [Secrets Management](./secrets-management.md) - Vault and External Secrets setup
