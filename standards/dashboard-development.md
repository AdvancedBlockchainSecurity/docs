# Dashboard Development Standards

**Version:** 2.0.0
**Last Updated:** November 27, 2025
**Status:** Active

> **Major Update (v2.0.0):** Dashboard now runs inside Minikube and is accessed via Traefik ingress controller. Do NOT run `npm run dev` locally - see [Port-Forwarding Standards](./port-forwarding.md) for the correct setup.

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

**IMPORTANT:** With the Traefik migration, you only need the Traefik port-forward for dashboard access. Traefik routes requests to both dashboard and API services.

```bash
# Kill any existing port-forwards first
pkill -f "kubectl port-forward" 2>/dev/null

# Wait for processes to die
sleep 2

# 1. Traefik Ingress (PRIMARY - routes to dashboard AND API)
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
- `http://127.0.0.1:3000` → Dashboard UI (served by dashboard pod)
- `http://127.0.0.1:3000/api/v1/*` → API Service (routed by Traefik based on path prefix)

This mirrors production architecture where all traffic goes through a single ingress point.

**Why NOT use direct port-forward to API service?**
- Port-forwarding to a **service** creates a connection to the underlying pods
- Port-forwarding to a **deployment** automatically handles pod restarts
- When a pod is replaced (during rollout), deployment port-forward reconnects automatically
- Service port-forward will die when the old pod terminates

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

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Local Development Setup](./local-development-setup.md) - Local development standards and setup
- [Testing & Deployment](./testing-deployment.md) - Testing and deployment workflows
