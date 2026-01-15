# Domain Management Standards

**Version:** 1.1.0
**Last Updated:** January 15, 2026
**Status:** Active

## Overview

This document defines the domain configuration strategy for BlockSecOps across environments:

| Environment | Domain | Purpose |
|-------------|--------|---------|
| **Local (minikube)** | `127.0.0.1`, `localhost` | Developer laptops |
| **Server (kubeadm)** | `app.blocksecops.local` | Pre-production testing on PowerEdge R720 |
| **Production (GCP)** | `app.blocksecops.com` | Production deployment |

## Architecture

BlockSecOps uses **Kustomize overlays** to manage environment-specific configurations. Domain/host values are NOT hardcoded in application code - they are injected via:

1. **Traefik IngressRoutes** - Route traffic based on hostname
2. **ConfigMaps** - Environment variables for services
3. **CORS Configuration** - API allowed origins

```
k8s/overlays/
├── local/          # minikube (127.0.0.1, localhost)
├── server/         # PowerEdge R720 (app.blocksecops.local) [NEW]
├── staging/        # GCP staging (staging.blocksecops.com)
└── production/     # GCP production (app.blocksecops.com)
```

---

## Environment Configuration

### Local Development (minikube)

**Access:** `http://127.0.0.1:3000`

Uses `minikube tunnel` with LoadBalancer services. No DNS required.

**Setup (one-time):**
```bash
# Start minikube tunnel in tmux (recommended)
tmux new -s tunnel -d 'minikube tunnel'
```

**Daily Workflow:** None required - services are always available with tunnel running.

**Verification:**
```bash
# Test dashboard
curl http://127.0.0.1:3000

# Test API
curl http://127.0.0.1:3000/api/v1/health/live
```

**Files:**
- `k8s/overlays/local/*/ingressroute.yaml` - Host rules for `localhost` and `127.0.0.1`
- `k8s/overlays/local/api-service/configmap-patch.yaml` - CORS origins

### Server Testing (PowerEdge R720)

**Access:** `http://app.blocksecops.local` (after DNS/hosts setup)

**Node IP:** `192.168.86.225`

**Domain Access (standard, with hostPort 80):**
| Service | URL |
|---------|-----|
| Dashboard | `http://app.blocksecops.local` |
| API | `http://app.blocksecops.local/api/v1/...` |
| Direct IP | `http://192.168.86.225` |

**Setup for app.blocksecops.local:**

1. **Add to /etc/hosts on SERVER itself (REQUIRED for local API testing):**
   ```bash
   # SSH to server and add entry so server can resolve its own domain
   echo "127.0.0.1  app.blocksecops.local" | sudo tee -a /etc/hosts
   ```

   > **Why this is required:** Without this entry, API calls from the server itself (e.g., `curl http://app.blocksecops.local`) fail with DNS resolution errors. This is needed for health checks, monitoring, and debugging.

2. **Add to /etc/hosts on CLIENT machines:**
   ```bash
   # Add to /etc/hosts (Linux/Mac) or C:\Windows\System32\drivers\etc\hosts (Windows)
   echo "192.168.86.225  app.blocksecops.local" | sudo tee -a /etc/hosts
   ```

3. **Server overlay is already created** at `blocksecops-gcp-infrastructure/k8s/overlays/server/`

**Verification:**
```bash
# From server itself
curl http://app.blocksecops.local/api/v1/health/live

# From client machine
curl http://app.blocksecops.local/api/v1/health/live
```

### Production (GCP)

**Access:** `https://app.blocksecops.com`

Uses GCP Load Balancer with TLS certificates via cert-manager.

**Daily Workflow:** None required - services are managed by infrastructure.

**Verification:**
```bash
# Test dashboard
curl https://app.blocksecops.com

# Test API
curl https://app.blocksecops.com/api/v1/health/live
```

**Files:**
- `k8s/overlays/gcp-production/*/ingressroute.yaml` - Host rules for `app.blocksecops.com`
- `k8s/overlays/gcp-production/api-service/configmap-patch.yaml` - Production CORS

---

## Creating Server Overlay

To transition from NodePort access to domain-based access on the PowerEdge server:

### Step 1: Create Server Overlay Directory

```bash
cd /home/pwner/Git/blocksecops-aws-infrastructure/k8s/overlays
mkdir -p server/api-service server/dashboard server/traefik
```

### Step 2: API Service Configuration

**File:** `k8s/overlays/server/api-service/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/api-service

patches:
  - path: configmap-patch.yaml
  - path: ingressroute.yaml
```

**File:** `k8s/overlays/server/api-service/configmap-patch.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-service-config
data:
  cors_origins: "http://app.blocksecops.local,http://192.168.86.225:30300"
  dashboard_base_url: "http://app.blocksecops.local"
```

**File:** `k8s/overlays/server/api-service/ingressroute.yaml`
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: api-service
  namespace: api-service-local
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`app.blocksecops.local`) && PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: api-service
          port: 8000
```

### Step 3: Dashboard Configuration

**File:** `k8s/overlays/server/dashboard/ingressroute.yaml`
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: dashboard
  namespace: dashboard-local
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`app.blocksecops.local`) && !PathPrefix(`/api/v1`)
      kind: Rule
      services:
        - name: dashboard
          port: 3000
```

### Step 4: Apply Server Overlay

```bash
# Apply API service with server overlay
kubectl apply -k k8s/overlays/server/api-service/

# Apply dashboard with server overlay
kubectl apply -k k8s/overlays/server/dashboard/

# Restart deployments to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## GCP Migration Checklist

When ready to deploy to GCP with `app.blocksecops.com`:

### Prerequisites

- [ ] GCP project created
- [ ] GKE cluster provisioned
- [ ] DNS A record: `app.blocksecops.com` → GCP Load Balancer IP
- [ ] DNS A record: `api.blocksecops.com` → GCP Load Balancer IP (if separate)

### Configuration Updates

1. **Verify Production Overlay Exists:**
   ```bash
   ls -la k8s/overlays/production/
   ```

2. **Update CORS Origins** (`k8s/overlays/production/api-service/configmap-patch.yaml`):
   ```yaml
   data:
     CORS_ORIGINS: "https://app.blocksecops.com,https://www.blocksecops.com"
     ALLOWED_HOSTS: "api.blocksecops.com,*.blocksecops.com"
   ```

3. **Verify IngressRoute** (`k8s/overlays/production/dashboard/ingressroute.yaml`):
   ```yaml
   spec:
     routes:
       - match: Host(`app.blocksecops.com`)
         kind: Rule
         services:
           - name: dashboard
             port: 3000
   ```

4. **Configure TLS with cert-manager:**
   ```yaml
   # k8s/overlays/production/certificate.yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: blocksecops-tls
   spec:
     secretName: blocksecops-tls-secret
     issuerRef:
       name: letsencrypt-prod
       kind: ClusterIssuer
     dnsNames:
       - app.blocksecops.com
       - api.blocksecops.com
   ```

5. **Update Traefik to use TLS:**
   ```yaml
   spec:
     entryPoints:
       - websecure  # HTTPS instead of web
     tls:
       secretName: blocksecops-tls-secret
   ```

### Deployment Steps

```bash
# 1. Connect to GKE cluster
gcloud container clusters get-credentials blocksecops-prod --zone us-central1-a

# 2. Apply infrastructure (PostgreSQL, Redis, Vault)
kubectl apply -k k8s/overlays/production/postgresql/
kubectl apply -k k8s/overlays/production/redis/
kubectl apply -k k8s/overlays/production/vault/

# 3. Apply cert-manager and certificates
kubectl apply -k k8s/overlays/production/cert-manager/

# 4. Apply Traefik with TLS
kubectl apply -k k8s/overlays/production/traefik/

# 5. Apply application services
kubectl apply -k k8s/overlays/production/api-service/
kubectl apply -k k8s/overlays/production/dashboard/
# ... other services

# 6. Verify TLS certificate
kubectl get certificate -A
kubectl describe certificate blocksecops-tls -n traefik

# 7. Test HTTPS access
curl https://app.blocksecops.com/api/v1/health/live
```

---

## Configuration Reference

### Files That Contain Domain Configuration

| File | Purpose | Domains |
|------|---------|---------|
| `api-service/k8s/overlays/*/configmap-patch.yaml` | CORS origins | All allowed origins |
| `api-service/src/infrastructure/config.py` | Default CORS | `localhost`, `127.0.0.1` |
| `dashboard/k8s/overlays/*/ingressroute.yaml` | Dashboard routing | Host match rules |
| `*/k8s/overlays/production/ingressroute.yaml` | Production routing | `app.blocksecops.com` |
| `dashboard/src/utils/env.ts` | Frontend defaults | Fallback URLs |

### Environment Variables

| Variable | Service | Purpose |
|----------|---------|---------|
| `CORS_ORIGINS` | API Service | Allowed CORS origins (comma-separated) |
| `ALLOWED_HOSTS` | API Service | Allowed Host headers |
| `DASHBOARD_BASE_URL` | API Service | URL for notification links |
| `VITE_API_URL` | Dashboard | API endpoint (build-time) |
| `VITE_WS_URL` | Dashboard | WebSocket endpoint (build-time) |

---

## Troubleshooting

### CORS Errors

**Symptom:** Browser console shows "Access-Control-Allow-Origin" errors

**Solution:**
1. Check API service logs: `kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service`
2. Verify CORS config: `kubectl get configmap api-service-config -n api-service-local -o yaml`
3. Add missing origin to `cors_origins` in configmap
4. Restart API service: `kubectl rollout restart deployment/api-service -n api-service-local`

### DNS Not Resolving

**Symptom:** `app.blocksecops.local` doesn't resolve

**Solution:**
1. Verify /etc/hosts entry: `cat /etc/hosts | grep blocksecops`
2. Flush DNS cache:
   - Mac: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`
   - Linux: `sudo systemd-resolve --flush-caches`
3. Test with IP directly: `curl http://192.168.86.225:30180`

### IngressRoute Not Matching

**Symptom:** 404 errors when accessing via domain

**Solution:**
1. Check IngressRoute: `kubectl get ingressroute -A`
2. Describe route: `kubectl describe ingressroute <name> -n <namespace>`
3. Verify Traefik logs: `kubectl logs -n traefik-local -l app.kubernetes.io/name=traefik`
4. Test Host header: `curl -H "Host: app.blocksecops.local" http://192.168.86.225:30180`

---

## Security Considerations

### Production Requirements

1. **Always use HTTPS in production** - Never expose HTTP endpoints publicly
2. **Restrict CORS origins** - Only allow known domains, never use `*`
3. **Use separate domains for API** - Consider `api.blocksecops.com` for API-only access
4. **Enable HSTS** - Force HTTPS with Strict-Transport-Security header
5. **CSP headers** - Configure Content-Security-Policy for frontend

### Development Exceptions

For local/server testing only:
- HTTP is acceptable (no TLS certificates needed)
- CORS can include multiple test origins
- `.local` domains are fine for internal testing

---

**See Also:**
- [Service Access Standards](./port-forwarding.md) - Always-available access patterns
- [Service Availability](./service-availability.md) - Service availability principles
- [Testing & Deployment](./testing-deployment.md) - Deployment procedures
- [Core Development Rules](./core-development-rules.md) - Development workflow
