# Dashboard Development Standards

**Version:** 2.4.0
**Last Updated:** December 30, 2025
**Status:** Active

> **Major Update (v2.4.0):** Dashboard builds use production mode with `serve -s dist`. Environment variables are baked in at build time via Docker build args. See [Frontend Build-Time Environment Variables](./frontend-build-env.md).
>
> **Major Update (v2.3.0):** All traffic MUST go through Traefik ingress controller. Port-forward to Traefik, NOT directly to services. This ensures API routing works correctly.

## Production Parity Principle

**CRITICAL REQUIREMENT:** Local development MUST replicate production routing and architecture.

| Aspect | Local Environment | Production Environment | Parity Required |
|--------|-------------------|------------------------|-----------------|
| Ingress Controller | Traefik v3.6+ | Traefik v3.6+ | **YES** |
| API Routing | Traefik routes `/api/*` to API service | Traefik routes `/api/*` to API service | **YES** |
| Single Entry Point | All traffic through Traefik on port 3000 | All traffic through ingress | **YES** |
| Container Runtime | Minikube Docker | AWS EKS | Similar |
| TLS/SSL | Self-signed (optional) | cert-manager | Acceptable deviation |

### Deviation Notification Requirement

**If production parity cannot be achieved for any reason:**
1. **STOP** - Do not proceed with a non-production-like solution
2. **DOCUMENT** - Create an issue describing the deviation
3. **NOTIFY** - Alert the team lead before implementing
4. **DECIDE** - Wait for approval on how to proceed

This ensures we catch production issues during local development, not after deployment.

## Anti-Patterns - DO NOT

| Anti-Pattern | Why It's Wrong | Correct Approach |
|--------------|----------------|------------------|
| Running `npm run dev` in container | Development server differs from production | Use production build with `serve -s dist` |
| Running `npm run dev` locally | Dashboard must run in cluster to match production architecture | Access via Traefik port-forward |
| Port-forward directly to dashboard | Bypasses Traefik, breaks API routing | Port-forward to Traefik: `kubectl port-forward -n traefik-local svc/traefik 3000:80` |
| Port-forward directly to API on separate port | Doesn't test production routing paths | Access API through Traefik at `localhost:3000/api/v1/*` |
| Direct API calls from localhost | Bypasses Traefik routing, doesn't test ingress paths | Access API through Traefik at `localhost:3000/api/v1/*` |
| Building dashboard outside cluster | Images must be built in Minikube Docker context | Use `eval $(minikube docker-env)` before `docker build` |

**The dashboard is NEVER started locally. It ALWAYS runs inside the Kubernetes cluster with a PRODUCTION BUILD.**

## CRITICAL: Python 3.13 Compatibility Issue

**Problem:** The API service uses Python 3.13, which has stricter greenlet handling for SQLAlchemy async sessions. Direct use of `model_validate()` on SQLAlchemy models causes `MissingGreenlet` errors that result in 500 Internal Server Errors.

**Error Signature:**
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for <ModelName>
<field_name>
  Error extracting attribute: MissingGreenlet: greenlet_spawn has not been called;
  can't call await_only() here. Was IO attempted in an unexpected place?
```

**Root Cause:** SQLAlchemy models have lazy-loaded relationships. When Pydantic tries to validate the model outside an async session context, Python 3.13's stricter greenlet handling prevents lazy loading.

**Solution:** ALWAYS use helper functions from `src/infrastructure/database/helpers.py`:

```python
from src.infrastructure.database.helpers import to_pydantic, to_pydantic_list

# ❌ WRONG - Will cause MissingGreenlet error
scan_response = ScanResponse.model_validate(scan)

# ✅ CORRECT - Refreshes model before validation
scan_response = await to_pydantic(db, scan, ScanResponse)

# For lists:
scans = await to_pydantic_list(db, scan_models, ScanResponse)
```

**Reference:** See `/Users/pwner/Git/ABS/blocksecops-api-service/docs/PYTHON-3.13-COMPATIBILITY.md` for full details.

## Proper Dashboard Startup Procedure

**CRITICAL:** The dashboard runs inside Minikube and is accessed via Traefik ingress. **DO NOT** run `npm run dev` locally - this will not work correctly with the API routing.

### Step 1: Start Minikube and Services

```bash
# 1. Ensure Minikube is running
minikube status

# 2. If not running, start it
minikube start

# 3. Verify all services are deployed and running
kubectl get pods -A | grep -E "api-service|dashboard|postgresql|redis|traefik"

# Expected output - all should show "Running" status:
# api-service-local       api-service-xxxxx          1/1     Running   0          10m
# dashboard-local         dashboard-xxxxx            1/1     Running   0          10m
# postgresql-local        postgresql-xxxxx           1/1     Running   0          2d
# redis-local             redis-xxxxx                1/1     Running   0          2d
# traefik-local           traefik-xxxxx              1/1     Running   0          2d
```

### Step 2: Verify Services Have Endpoints

**CRITICAL:** Services with no endpoints cannot be accessed via Traefik!

```bash
# Check all service endpoints
kubectl get endpoints -n api-service-local api-service
kubectl get endpoints -n dashboard-local dashboard
kubectl get endpoints -n postgresql-local postgresql
kubectl get endpoints -n redis-local redis
kubectl get endpoints -n traefik-local traefik

# ✅ GOOD: Shows IP addresses
# NAME          ENDPOINTS                AGE
# api-service   10.244.0.14:8000         2d

# ❌ BAD: No endpoints (selector mismatch)
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**If any service shows `<none>` for endpoints:**
- Review [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)
- Fix `includeSelectors: false` in kustomization.yaml
- Reapply: `kubectl apply -k k8s/overlays/local/<service>/`

### Step 3: Start Required Port-Forwards

**CRITICAL:** You MUST port-forward to **Traefik**, NOT directly to dashboard or API services. Direct port-forwards break API routing and don't test the production ingress path.

```bash
# Kill any existing port-forwards first
pkill -f "kubectl port-forward" 2>/dev/null

# Wait for processes to die
sleep 2

# 1. Traefik Ingress (PRIMARY - routes to BOTH dashboard AND API)
#    This is the ONLY way to access the dashboard correctly!
kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &
echo "Traefik port-forward started on 3000"

# 2. PostgreSQL (required for direct database access/debugging)
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 > /tmp/pf-postgresql.log 2>&1 &
echo "PostgreSQL port-forward started"

# 3. Redis (required for direct cache access/debugging)
kubectl port-forward -n redis-local svc/redis 6379:6379 > /tmp/pf-redis.log 2>&1 &
echo "Redis port-forward started"

# Wait for port-forwards to stabilize
sleep 3

# Verify port-forwards are active
lsof -i :3000,5432,6379 | grep LISTEN
```

**How Traefik Routing Works:**
- `http://127.0.0.1:3000/` → Dashboard UI (served by dashboard pod)
- `http://127.0.0.1:3000/api/v1/*` → API Service (routed by Traefik based on path prefix)

This mirrors production architecture where all traffic goes through a single ingress point.

**INCORRECT Port-Forward Setup (DO NOT USE):**
```bash
# ❌ WRONG - Direct port-forward to dashboard
kubectl port-forward -n dashboard-local svc/dashboard 3000:3000

# ❌ WRONG - Direct port-forward to API on separate port
kubectl port-forward -n api-service-local svc/api-service 8000:8000
```

**Why direct port-forwards are WRONG:**
- Dashboard makes API calls to `/api/v1/*` (relative URL)
- With direct dashboard port-forward, these requests go to the dashboard container
- Dashboard container has no API - requests fail
- This causes auth failures, missing contracts, and other routing issues

**CORRECT Port-Forward Setup (ALWAYS USE):**
```bash
# ✅ CORRECT - Port-forward to Traefik which routes both services
kubectl port-forward -n traefik-local svc/traefik 3000:80
```

**Expected output:**
```
kubectl  48801  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 3000
kubectl  48802  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 5432
kubectl  48803  0.0  0.1 35597176  24408   ??  SN    6:21PM   0:00.54 kubectl port-forward... 6379
```

### Step 4: Verify Dashboard and API Health

**Test that both dashboard and API are accessible via Traefik:**

```bash
# Test dashboard (should return HTML)
curl -s http://127.0.0.1:3000 | head -5
# Expected: <!doctype html>...

# Test API health via Traefik routing
curl -s http://127.0.0.1:3000/api/v1/health/live | jq '.'

# Expected output:
# {
#   "status": "healthy",
#   "service": "BlockSecOps API Service",
#   "version": "0.1.0",
#   "timestamp": "2025-10-17T18:25:00.123456"
# }

# Test API readiness (checks database connection)
curl -s http://127.0.0.1:3000/api/v1/health/ready | jq '.'

# Expected output:
# {
#   "status": "ready",
#   "database": "connected",
#   "redis": "connected"
# }
```

**If health checks fail:**

```bash
# 1. Check Traefik port-forward is running
lsof -i :3000 | grep LISTEN

# 2. Check dashboard pod logs
kubectl logs -n dashboard-local deployment/dashboard --tail=50

# 3. Check API pod logs
kubectl logs -n api-service-local deployment/api-service --tail=50

# 4. Verify IngressRoutes are configured
kubectl get ingressroute -n dashboard-local
kubectl get ingressroute -n api-service-local

# 5. Common issues:
#    - Traefik port-forward not running
#    - IngressRoute misconfigured
#    - Dashboard/API pods not running
#    - Service has no endpoints
```

### Step 5: Access Dashboard

**Open browser to http://127.0.0.1:3000**

The dashboard runs inside Minikube - you do NOT need to run `npm run dev` locally.

**⚠️ COMMON MISTAKE:** Do NOT run `npm run dev` on your local machine!
- The dashboard uses relative URLs (`/api/v1`) for API requests
- These are routed by Traefik to the API service in the cluster
- Running locally would require a proxy configuration and defeats the purpose of the production-mirroring setup

### Step 6: Verify Dashboard Connectivity

```bash
# 1. Open browser to http://127.0.0.1:3000

# 2. Open browser console (F12)

# 3. Check for connection errors
#    ✅ GOOD: No errors, dashboard loads, user info appears
#    ❌ BAD: "Network Error", "ERR_CONNECTION_REFUSED", 404 on /api calls

# 4. If errors occur, check Traefik port-forward:
curl -s http://127.0.0.1:3000/api/v1/health/live
```

## Troubleshooting Dashboard Issues

### Issue: "Network Error" or "ERR_CONNECTION_REFUSED"

**Root Cause:** Traefik port-forward is not running.

**Solution:**
```bash
# 1. Check if Traefik port-forward is running
lsof -i :3000 | grep LISTEN

# 2. If not running, restart it
kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &

# 3. Wait and test
sleep 3
curl http://127.0.0.1:3000/api/v1/health/live

# 4. Refresh dashboard browser page
```

### Issue: 404 on API calls

**Root Cause:** Traefik IngressRoute for API service is not configured or missing.

**Solution:**
```bash
# 1. Check IngressRoute exists
kubectl get ingressroute -n api-service-local

# 2. If missing, apply the API service overlay
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/

# 3. Verify IngressRoute has correct path matching
kubectl get ingressroute -n api-service-local api-service -o yaml | grep -A5 "match:"
# Should show: (Host(`localhost`) || Host(`127.0.0.1`)) && PathPrefix(`/api`)
```

### Issue: Port-forward keeps dying

**Root Cause:** Traefik pod restarted or port-forward process died.

**Solution:**
```bash
# 1. Check Traefik pod is running
kubectl get pods -n traefik-local

# 2. Restart Traefik port-forward
pkill -f "port-forward.*traefik" 2>/dev/null
sleep 2
kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &

# 3. Verify working
sleep 2
curl -s http://127.0.0.1:3000/api/v1/health/live
```

### Issue: Dashboard pod not running

**Symptom:**
```bash
# Traefik is up but dashboard shows 503/502 error
curl http://127.0.0.1:3000
# Returns Traefik error page
```

**Solution:**
```bash
# 1. Check dashboard pod
kubectl get pods -n dashboard-local

# 2. If not running or crashed, check logs
kubectl logs -n dashboard-local deployment/dashboard --tail=50

# 3. If pod is missing, deploy it
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-dashboard/k8s/overlays/local/

# 4. Wait for pod to be ready
kubectl rollout status -n dashboard-local deployment/dashboard
```

**Prevention:**
- **Use deployment-based port-forwards** instead of service/pod port-forwards
- Deployment port-forwards automatically reconnect when pods are replaced
- After any `kubectl rollout restart` or config change, restart port-forwards
- Consider adding port-forward health checks to startup scripts

**Example - After Config Changes:**
```bash
# Scenario: Updated CORS configuration in configmap

# 1. Apply config changes
kubectl apply -k k8s/overlays/local/api-service

# 2. Restart deployment to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 3. IMMEDIATELY restart port-forwards (pod has been replaced)
lsof -ti:8000 | xargs kill -9 2>/dev/null
sleep 2
kubectl port-forward -n api-service-local deployment/api-service 8000:8000 --address=127.0.0.1 &

# 4. Verify API is accessible
curl -s http://127.0.0.1:8000/api/v1/health/live
```

**Why deployment port-forward is better:**
- Service port-forward: Goes through service → endpoint → pod (breaks when pod changes)
- Pod port-forward: Direct to specific pod (breaks when that pod is deleted)
- Deployment port-forward: Follows deployment's current pod (auto-reconnects on pod replacement)

### Issue: "MissingGreenlet" error when creating scans

**Root Cause:** Endpoint uses direct `model_validate()` instead of helper functions.

**Solution:** All endpoints MUST use `to_pydantic()` or `to_pydantic_list()`:

```python
# Find the problematic endpoint
grep -n "model_validate" src/presentation/api/v1/endpoints/*.py

# Replace with helper function:
from src.infrastructure.database.helpers import to_pydantic

# Before:
return ScanResponse.model_validate(scan)

# After:
return await to_pydantic(db, scan, ScanResponse)
```

**Reference:** See Python 3.13 Compatibility section above and `/Users/pwner/Git/ABS/blocksecops-api-service/docs/PYTHON-3.13-COMPATIBILITY.md`

### Issue: Service has no endpoints

**Symptom:**
```bash
kubectl get endpoints -n api-service-local api-service
# NAME          ENDPOINTS   AGE
# api-service   <none>      2d
```

**Root Cause:** `includeSelectors: true` in kustomization.yaml adds too many labels to selector.

**Solution:** See [Local Development Setup - Kubernetes Service Selector Standards](./local-development-setup.md#kubernetes-service-selector-standards)

## Dashboard Development Workflow

**Daily development workflow:**

```bash
# 1. Verify Minikube is running
minikube status

# 2. Check all services are healthy
kubectl get pods -A | grep -v "kube-system"

# 3. Start Traefik port-forward (if not already running)
lsof -i :3000 | grep LISTEN || {
  kubectl port-forward -n traefik-local svc/traefik 3000:80 > /tmp/pf-traefik.log 2>&1 &
  sleep 3
}

# 4. Optionally start database/cache port-forwards for direct debugging
lsof -i :5432 | grep LISTEN || kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 > /tmp/pf-postgresql.log 2>&1 &
lsof -i :6379 | grep LISTEN || kubectl port-forward -n redis-local svc/redis 6379:6379 > /tmp/pf-redis.log 2>&1 &

# 5. Verify dashboard and API are healthy via Traefik
curl -s http://127.0.0.1:3000 | head -1  # Should return HTML
curl -s http://127.0.0.1:3000/api/v1/health/ready | jq '.status'

# 6. Open browser to http://127.0.0.1:3000

# 7. Develop and test features
#    NOTE: Dashboard runs inside Minikube - do NOT run npm run dev locally!
```

**After pulling code changes:**

```bash
# 1. Pull latest code
cd /Users/pwner/Git/ABS/blocksecops-api-service
git pull

# 2. Build new Docker image
eval $(minikube docker-env)
docker build -t api-service:0.3.20 .
docker tag api-service:0.3.20 api-service:latest

# 3. Update deployment
kubectl set image -n api-service-local deployment/api-service api-service=api-service:0.3.20

# 4. Wait for rollout
kubectl rollout status -n api-service-local deployment/api-service

# 5. Verify API health via Traefik
curl -s http://127.0.0.1:3000/api/v1/health/live

# 6. Refresh dashboard browser page
```

## Dashboard Build Workflow (v2.4.0)

**IMPORTANT:** The dashboard uses Vite, which bakes environment variables into the JavaScript bundle at **build time**. You MUST pass required variables as Docker build args.

### Build Command

```bash
# 1. Switch to minikube's Docker daemon
eval $(minikube docker-env)

# 2. Source environment variables from .env.local
cd /Users/pwner/Git/ABS
source blocksecops-dashboard/.env.local

# 3. Build with required build args (DO NOT hardcode in Dockerfile!)
docker build --no-cache \
  --build-arg VITE_SUPABASE_URL=$VITE_SUPABASE_URL \
  --build-arg VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY \
  --build-arg VITE_WS_URL=$VITE_WS_URL \
  --build-arg VITE_WS_ENABLED=$VITE_WS_ENABLED \
  -t blocksecops-dashboard:0.19.0 \
  -f blocksecops-dashboard/Dockerfile .

# 4. Tag as latest
docker tag blocksecops-dashboard:0.19.0 blocksecops-dashboard:latest

# 5. Update kustomization.yaml version
# Edit blocksecops-dashboard/k8s/overlays/local/kustomization.yaml

# 6. Deploy
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
kubectl rollout restart deployment/dashboard -n dashboard-local
kubectl rollout status deployment/dashboard -n dashboard-local
```

### Required Build Arguments

| Build Arg | Required | Description |
|-----------|----------|-------------|
| `VITE_SUPABASE_URL` | **Yes** | Supabase project URL |
| `VITE_SUPABASE_ANON_KEY` | **Yes** | Supabase anonymous key |
| `VITE_WS_URL` | No (default: `ws://127.0.0.1:8003/ws`) | WebSocket endpoint |
| `VITE_WS_ENABLED` | No (default: `true`) | Enable WebSocket |

### Why Build Args, Not Hardcoded Values?

The Dockerfile **validates** that required build args are provided and will fail if they're missing. This prevents accidentally committing sensitive values to Git.

**Standard Reference:** See [Frontend Build-Time Environment Variables](./frontend-build-env.md) for complete details on:
- Security classification (public vs private variables)
- `.env.local` vs `.env.example` patterns
- CI/CD integration

## Dashboard Development Checklist

**Before starting development:**

- [ ] Minikube running (`minikube status`)
- [ ] All services deployed and healthy (`kubectl get pods -A`)
- [ ] All services have endpoints (`kubectl get endpoints -A | grep -v kube-system`)
- [ ] Traefik port-forward active on 3000 (`lsof -i :3000 | grep LISTEN`)
- [ ] PostgreSQL port-forward active on 5432 (optional, for direct DB access)
- [ ] Redis port-forward active on 6379 (optional, for direct cache access)
- [ ] Dashboard accessible via Traefik (`curl -s http://127.0.0.1:3000 | head -1`)
- [ ] API health check passing via Traefik (`curl http://127.0.0.1:3000/api/v1/health/ready`)
- [ ] Can access dashboard at `http://127.0.0.1:3000`
- [ ] No console errors in browser (F12 → Console tab)
- [ ] **NOT running `npm run dev` locally** (dashboard runs inside Minikube!)

**After code changes:**

- [ ] Code changes committed to Git
- [ ] Docker image built with incremented version AND tagged as `:latest`
- [ ] Deployment updated to new image version
- [ ] Rollout completed successfully
- [ ] Traefik port-forward still active (restart if needed)
- [ ] API health check passing via Traefik
- [ ] Dashboard refreshed in browser
- [ ] Feature tested and verified

---

## Real-Time Updates and Notifications (v2.1.0)

**Added:** November 29, 2025

The dashboard includes a real-time notification system that integrates with WebSocket events for live scan updates and toast notifications.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Notification Service (8003)                 │
│  WebSocket: ws://127.0.0.1:8003/ws/                         │
└─────────────────┬───────────────────────────────────────────┘
                  │ WebSocket Events
                  ▼
┌─────────────────────────────────────────────────────────────┐
│               WebSocketManager (Singleton)                  │
│  Location: src/lib/websocket/WebSocketManager.ts            │
│  Events: scan_progress, scan_completed, vulnerability_found │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                useNotifications Hook                        │
│  Location: src/hooks/useNotifications.ts                    │
│  Subscribes to WebSocket events and triggers toasts         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                   ToastContext                              │
│  Location: src/contexts/ToastContext.tsx                    │
│  Manages toast state, auto-dismiss, actions                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  ToastContainer                             │
│  Location: src/components/common/ToastContainer.tsx         │
│  Renders toast notifications UI                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `ToastContext` | `src/contexts/ToastContext.tsx` | Toast state management and provider |
| `ToastContainer` | `src/components/common/ToastContainer.tsx` | Toast UI rendering |
| `useNotifications` | `src/hooks/useNotifications.ts` | WebSocket-to-toast integration |
| `useNotify` | `src/hooks/useNotifications.ts` | Manual notification helper |
| `NotificationHandler` | `src/components/common/NotificationHandler.tsx` | Global notification subscriber |

### Toast Types

| Type | Color | Duration | Use Case |
|------|-------|----------|----------|
| `success` | Green | 4s | Scan completed, export successful |
| `error` | Red | 6s | Scan failed, API errors |
| `warning` | Yellow | 5s | Quota near limit, issues found |
| `info` | Blue | 4s | Scan started, general info |

### WebSocket Events

The notification system subscribes to these events from `WebSocketManager`:

| Event | Handler | Toast Type |
|-------|---------|------------|
| `connection_status` | Connection state changes | success/warning |
| `scan_progress` | Scan milestone updates (25%, 50%, 75%, 100%) | info |
| `scan_completed` | Scan finished with results | success/warning/error |
| `vulnerability_found` | New vulnerability detected | severity-based |

### Notification Settings

```typescript
interface NotificationSettings {
  scanProgress: boolean;      // Show progress milestones (default: false - too noisy)
  scanCompletion: boolean;    // Show scan completion (default: true)
  vulnerabilities: boolean;   // Show vulnerability alerts (default: true)
  criticalOnly: boolean;      // Only high/critical severity (default: false)
  connectionStatus: boolean;  // Show connection changes (default: true)
}
```

### Usage Examples

**Using useNotify for manual notifications:**

```typescript
import { useNotify } from '@/hooks/useNotifications';

function MyScanComponent() {
  const notify = useNotify();

  const handleScanStart = async () => {
    notify.scanStarted(scanId, 'MyContract.sol');
    try {
      await startScan(scanId);
    } catch (error) {
      notify.scanFailed(error.message);
    }
  };

  return <button onClick={handleScanStart}>Start Scan</button>;
}
```

**Using useNotifications for WebSocket integration:**

```typescript
import { useNotifications } from '@/hooks/useNotifications';

function MyDashboard() {
  // Automatically subscribes to WebSocket events
  const notifications = useNotifications({
    scanCompletion: true,
    vulnerabilities: true,
    criticalOnly: false,
  });

  return <div>Dashboard with live notifications</div>;
}
```

### Auto-Refresh Feature

The Analytics dashboard includes auto-refresh functionality:

| Feature | Location | Behavior |
|---------|----------|----------|
| Auto-refresh toggle | `DashboardAnalytics.tsx` | Toggle on/off in header |
| Refresh interval | 30 seconds | Configurable via `AUTO_REFRESH_INTERVAL` |
| Live indicator | Header | Green dot when auto-refresh enabled |
| Last updated | Header | Shows time since last data fetch |
| Visibility refresh | `useEffect` | Refreshes data when tab becomes visible |

**Implementation:**

```typescript
// Auto-refresh with React Query
const { data, refetch } = useQuery({
  queryKey: ['analytics'],
  queryFn: fetchAnalytics,
  refetchInterval: autoRefreshEnabled ? 30000 : false,
  refetchIntervalInBackground: false,
});

// Refresh on tab visibility change
useEffect(() => {
  const handleVisibilityChange = () => {
    if (document.visibilityState === 'visible' && autoRefreshEnabled) {
      refetch();
    }
  };
  document.addEventListener('visibilitychange', handleVisibilityChange);
  return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
}, [autoRefreshEnabled, refetch]);
```

### Notification Service Port-Forward

For real-time WebSocket notifications, port-forward the notification service:

```bash
# Required for WebSocket notifications
kubectl port-forward -n notification-local svc/notification 8003:8003 &

# Test WebSocket endpoint
curl http://127.0.0.1:8003/
# Expected: {"message":"Solidity Security Notification Service","status":"running",...}
```

**Note:** The Notification Service is **optional** for basic dashboard usage. Only required for:
- Real-time scan status updates
- Live vulnerability alerts
- WebSocket-based notifications

### Troubleshooting Notifications

**Issue: Toasts not appearing**

1. Check `NotificationHandler` is in component tree (App.tsx)
2. Verify `ToastProvider` wraps the app
3. Check `ToastContainer` is rendered
4. Verify WebSocket connection in browser console

**Issue: WebSocket not connecting**

```bash
# Check notification service is running
kubectl get pods -n notification-local

# Check port-forward is active
lsof -i :8003 | grep LISTEN

# Restart port-forward
kubectl port-forward -n notification-local svc/notification 8003:8003 &
```

**Issue: Duplicate notifications**

The `useNotifications` hook tracks shown notifications in a `Set` to prevent duplicates. If duplicates appear, check:
1. Component is not mounted multiple times
2. WebSocket is not reconnecting rapidly

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Local Development Setup](./local-development-setup.md) - Local development standards and setup
- [Frontend Build-Time Environment Variables](./frontend-build-env.md) - Vite build args and environment variable handling
- [Testing & Deployment](./testing-deployment.md) - Testing and deployment workflows
- [Notification Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/notification-frontend.md) - Detailed notification system documentation
