# Local Development Setup Standards

**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## Access Endpoints

**MANDATORY endpoints for local development:**

| Service | Endpoint | Notes |
|---------|----------|-------|
| Dashboard | `http://127.0.0.1:3000` | Main dashboard with Supabase Auth (blocksecops-dashboard) |
| API Service | `http://127.0.0.1:8000` | FastAPI backend |
| API Docs | `http://127.0.0.1:8000/docs` | Swagger UI |
| Notification | `http://127.0.0.1:8003` | WebSocket server |
| Grafana | `http://127.0.0.1:3001` | Monitoring dashboard |
| Prometheus | `http://127.0.0.1:9090` | Metrics (when forwarded) |

## Port Forward Standards

**Standard port-forward script** (save as `scripts/port-forward-local.sh`):

```bash
#!/bin/bash
# Port forward all local development services

echo "Starting port forwards for local development..."

# Kill existing port forwards
lsof -ti:8000,8003,3001 | xargs kill -9 2>/dev/null

# Note: Dashboard runs via npm run dev (see dashboard-development.md)
# Runs directly on port 3000 - no port-forward needed

# API Service
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &
echo "✅ API Service: http://127.0.0.1:8000"

# Notification Service
kubectl port-forward -n notification-local svc/notification 8003:8003 &
echo "✅ Notification: http://127.0.0.1:8003"

# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80 &
echo "✅ Grafana: http://127.0.0.1:3001"

echo ""
echo "All port forwards active. Use 127.0.0.1 for all connections."
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
# ❌ INCORRECT: Let service pick next available port
npm run dev  # Picks port 3001, 3004, etc. when 3000 is occupied

# ✅ CORRECT: Free up the standard port
lsof -ti:3000 | xargs kill -9  # Kill process using port 3000
npm run dev  # Now uses port 3000
```

**When ports conflict during development:**

```bash
# 1. Identify what's using the port
lsof -i:3000

# 2. If it's an old/stale process, kill it
kill -9 <PID>

# 3. If it's a legitimate service, check if it should be running
ps aux | grep <process-name>

# 4. Restart the service on the correct port
# (Example for dashboard on 3000)
cd /Users/pwner/Git/ABS/blocksecops-dashboard
npm run dev
```

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

**Required `.env.local` for dashboard** (never commit this file):

```bash
# Dashboard local development environment
# Location: blocksecops-dashboard/.env.local

# MANDATORY: Use 127.0.0.1 for local development
VITE_API_BASE_URL=http://127.0.0.1:8000
VITE_WS_URL=ws://127.0.0.1:8003

# Optional
VITE_ENVIRONMENT=local
VITE_DEBUG=true
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

- [ ] Minikube cluster is running
- [ ] All required services deployed
- [ ] Port forwards configured to use `127.0.0.1`
- [ ] Dashboard running on correct port 3000 (via `npm run dev`)
- [ ] API service running on correct port 8000
- [ ] Dashboard `.env.local` uses `127.0.0.1` endpoints
- [ ] Backend CORS includes `127.0.0.1:3000`
- [ ] All services have endpoints: `kubectl get endpoints -n <namespace>`
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] Can access API docs at `http://127.0.0.1:8000/docs`

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Dashboard Development](./dashboard-development.md) - Dashboard-specific setup and workflows
- [Secrets Management](./secrets-management.md) - Vault and External Secrets setup
