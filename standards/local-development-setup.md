# Local Development Setup Standards

**Version:** 2.7.0
**Last Updated:** January 7, 2026
**Status:** Active

> **Update (v2.7.0):** Added External Service Integrations section with Stripe CLI webhook forwarding for local billing development.
>
> **Major Update (v2.6.0):** Simplified local development workflow. Harbor is no longer used for local development - images are built directly into minikube's Docker daemon for faster iteration.
>
> **Previous (v2.5.0):** Vault now uses persistent file storage with auto-unseal. Secrets persist across cluster restarts.
>
> **Previous (v2.2.0):** Added Local Overlay First Principle. All Kubernetes code MUST be developed and tested in the local overlay.

## Local Overlay First Principle

**CRITICAL REQUIREMENT:** All Kubernetes development targets the `local` overlay. This is our primary development and testing environment.

### Target Environment

| Aspect | Value |
|--------|-------|
| **Active Overlay** | `k8s/overlays/local/` |
| **Namespace Suffix** | `-local` (e.g., `api-service-local`) |
| **Deployment Target** | Minikube |

### Development Rules

1. **All new k8s code goes to local overlay first**
   - New services, patches, and configurations start in `k8s/overlays/local/`
   - Test thoroughly in local before considering other overlays
   - Local overlay is the source of truth for active development

2. **Deploy and test using local overlay**
   ```bash
   # Always deploy from local overlay
   kubectl apply -k k8s/overlays/local/

   # NOT from base or other overlays during development
   ```

3. **If something is missing, check other overlays**
   - Code may have been mistakenly placed in `staging/` or `production/` overlays
   - Common mistakes:
     - IngressRoutes in wrong overlay
     - ConfigMap patches in staging instead of local
     - Service patches missing from local
   - When found, copy/move the code to local overlay

### Overlay Recovery Checklist

If a resource is missing from local, check these locations:

```bash
# Check if resource exists in other overlays
ls k8s/overlays/staging/<service>/
ls k8s/overlays/production/<service>/

# Compare overlays to find missing files
diff -r k8s/overlays/local/<service>/ k8s/overlays/staging/<service>/
```

**Common misplaced resources:**
- `ingressroute.yaml` - Often created in staging first
- `configmap-patch.yaml` - Environment-specific values in wrong overlay
- `deployment-patch.yaml` - Resource limits may differ
- `middleware-*.yaml` - Traefik middlewares

### Overlay Structure Reference

```
k8s/
├── base/                    # Shared base manifests
│   └── <service>/
└── overlays/
    ├── local/               # ← PRIMARY DEVELOPMENT TARGET
    │   └── <service>/
    │       ├── kustomization.yaml
    │       ├── namespace.yaml
    │       ├── deployment-patch.yaml
    │       ├── configmap-patch.yaml
    │       ├── service-patch.yaml
    │       └── ingressroute.yaml
    ├── staging/             # Check here if local is missing resources
    └── production/          # Check here if local is missing resources
```

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

### External DNS Resolution Failure After Restart

**Symptom:** After laptop crash or Docker restart, pods cannot resolve external hostnames (e.g., Supabase for auth token validation).

```
socket.gaierror: [Errno -3] Temporary failure in name resolution
# or
Token verification failed: Failed to resolve 'huzjlpypdlelqnbjvxad.supabase.co'
```

**Root Cause:** CoreDNS forwards to Docker Desktop DNS (192.168.65.254) which becomes unresponsive after restarts.

**Fix:**

```bash
# 1. Update CoreDNS to use Google DNS directly
kubectl get configmap coredns -n kube-system -o json | \
  jq '.data.Corefile |= sub("forward . /etc/resolv.conf"; "forward . 8.8.8.8 8.8.4.4")' | \
  kubectl apply -f -

# 2. Restart CoreDNS pod
kubectl delete pod -n kube-system -l k8s-app=kube-dns

# 3. Add control-plane hostname (if kube-proxy failing)
minikube ssh "echo '192.168.49.2 control-plane.minikube.internal' | sudo tee -a /etc/hosts"

# 4. Restart affected pods
kubectl rollout restart deployment/api-service -n api-service-local
```

**Verification:**

```bash
# Test DNS from inside a pod
kubectl exec -n api-service-local deployment/api-service -- \
  python3 -c "import socket; print(socket.gethostbyname('google.com'))"
```

## Docker Image Build Workflow

For local development, images are built directly into minikube's Docker daemon. This is faster and simpler than using a registry.

> **Note:** Harbor is deployed in the cluster but is **not used for local development** due to the overhead of pushing/pulling images. Harbor is intended for staging/production workflows.

### Build and Deploy Workflow

```bash
# 1. Use minikube's Docker daemon (REQUIRED)
eval $(minikube docker-env)

# 2. Build with versioned tag
docker build -t <service>:<version> .

# 3. Tag as the name expected by kustomization
docker tag <service>:<version> <service>:latest

# 4. Update kustomization.yaml with new version
#    - Update images[].newTag
#    - Update labels app.kubernetes.io/version

# 5. Deploy via kustomization
kubectl apply -k k8s/overlays/local/<service>/
```

### Example: Building API Service

```bash
eval $(minikube docker-env)
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Build and tag
docker build -t api-service:0.4.1 .
docker tag api-service:0.4.1 api-service:latest

# Deploy
kubectl apply -k k8s/overlays/local/
```

### Why Direct Minikube Docker (Not Harbor)

| Direct Minikube Docker | Harbor Registry |
|------------------------|-----------------|
| No push/pull overhead | Requires push + pull |
| Instant availability | Network transfer time |
| Simple workflow | Requires socat proxy setup |
| Good for rapid iteration | Better for CI/CD pipelines |

**When to use Harbor:** Staging/production environments, CI/CD pipelines, or when testing registry-based deployments.

## Prometheus Metrics Instrumentation

All Python services expose Prometheus metrics on port 9090 using `prometheus-fastapi-instrumentator`.

### Service Metrics Endpoints

| Service | Namespace | Metrics Port | Endpoint |
|---------|-----------|--------------|----------|
| api-service | api-service-local | 9090 | /metrics |
| data-service | data-service-local | 9090 | /metrics |
| intelligence-engine | intelligence-engine-local | 9090 | /metrics |
| orchestration | orchestration-local | 9090 | /metrics |
| tool-integration | tool-integration-local | 9090 | /metrics |

### Database Exporters

| Exporter | Namespace | Port | Key Metrics |
|----------|-----------|------|-------------|
| postgres-exporter | postgresql-local | 9187 | pg_up, pg_stat_activity, pg_database_size |
| redis-exporter | redis-local | 9121 | redis_up, redis_connected_clients, redis_memory_used |

### Verify Metrics

```bash
# Check Python service metrics
kubectl exec -n api-service-local deployment/api-service -- curl -s localhost:9090/metrics | head -20

# Check database exporter metrics
kubectl exec -n postgresql-local deployment/postgres-exporter -- curl -s localhost:9187/metrics | head -20
kubectl exec -n redis-local deployment/redis-exporter -- curl -s localhost:9121/metrics | head -20
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
| PostgreSQL | `127.0.0.1:5432` | Database (optional, for debugging) |
| Redis | `127.0.0.1:6379` | Cache (optional, for debugging) |

**Optional/Disabled Services:**

| Service | Endpoint | Notes |
|---------|----------|-------|
| Grafana | `http://127.0.0.1:3001` | Monitoring (disabled by default) |
| Prometheus | `http://127.0.0.1:9090` | Metrics (disabled by default) |
| Harbor | N/A | Not used for local dev (images built in minikube) |

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

# Grafana (optional - disabled by default for resource savings)
# kubectl port-forward -n monitoring svc/monitoring-grafana 3001:80 > /tmp/pf-grafana.log 2>&1 &
# echo "✅ Grafana: http://127.0.0.1:3001"

# Harbor Container Registry (NOT USED for local dev - images built directly in minikube)
# kubectl port-forward -n harbor-local svc/harbor-core 8080:80 > /tmp/pf-harbor.log 2>&1 &
# echo "✅ Harbor: http://127.0.0.1:8080"

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
| Dashboard | 3000 | Main Dashboard UI | Primary user interface via Traefik |
| API Service | 8000 | Backend API | FastAPI application (routed via Traefik) |
| Notification | 8003 | WebSocket | Real-time notifications |
| Vault | 8200 | Secret Management | HashiCorp Vault (persistent file storage, auto-unseal) |
| PostgreSQL | 5432 | Database | Optional, for debugging |
| Redis | 6379 | Cache | Optional, for debugging |
| Grafana | 3001 | Monitoring | Disabled by default |

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

## External Service Integrations

### Stripe CLI (Billing/Payments Development)

When developing Stripe billing integration, use the Stripe CLI to forward webhook events to your local environment.

**Installation:**
```bash
# macOS
brew install stripe/stripe-cli/stripe

# Login to Stripe (will open browser for authentication)
stripe login
```

**Webhook Forwarding:**
```bash
# Forward Stripe webhooks to local API via Traefik
stripe listen --forward-to http://127.0.0.1:3000/api/v1/webhooks/stripe

# Output will show webhook signing secret:
# > Ready! Your webhook signing secret is whsec_xxxxx (^C to quit)
```

**Important:** Copy the `whsec_xxxxx` signing secret and add it to your local environment or Vault for webhook signature verification.

**Test Events:**
```bash
# Trigger a test event
stripe trigger checkout.session.completed

# Trigger subscription events
stripe trigger customer.subscription.created
stripe trigger invoice.paid
```

**Test Card Numbers:**

| Card Number | Result |
|-------------|--------|
| `4242424242424242` | Success |
| `4000000000000341` | Card declined |
| `4000000000009995` | Insufficient funds |
| `4000000000000002` | Declined (generic) |

**Port Note:** Webhooks are forwarded to Traefik (port 3000) which routes `/api/v1/*` to the API service. Do NOT forward directly to port 8000 as that bypasses the ingress routing.

### Other External Services

| Service | CLI Tool | Forward Command |
|---------|----------|-----------------|
| Stripe | `stripe` | `stripe listen --forward-to http://127.0.0.1:3000/api/v1/webhooks/stripe` |
| GitHub | `gh` | N/A (uses outbound webhooks) |
| Supabase | N/A | Uses Supabase cloud (no local forwarding needed) |

---

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
